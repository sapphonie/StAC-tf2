/**
 * Utility functions for dealing with memory.
 */

#if defined __stocksoup_memory_included
	#endinput
#endif

#define __stocksoup_memory_included

/**
 * Loads a null-terminated string from the given address.
 * 
 * The function will return an empty string if the address corresponds to a nullptr.  This
 * functionality is present as a workaround for when an SDKCall that expects a char pointer
 * receives a nullptr and attempts to dereference it (see alliedmodders/sourcemod/issues/874).
 * 
 * If it is necessary to differentiate between an empty string and a null pointer, check if addr
 * is null before calling the function, or pass a reference to bIsNullPointer.
 * 
 * @return Number of bytes written.  0 is returned on an empty string or a null pointer.
 */
stock int LoadStringFromAddress(Address addr, char[] buffer, int maxlen,
		bool &bIsNullPointer = false) {
	if (!addr) {
		bIsNullPointer = true;
		return 0;
	}
	
	int c;
	char ch;
	do {
		ch = LoadFromAddress(addr + view_as<Address>(c), NumberType_Int8);
		buffer[c] = ch;
	} while (ch && ++c < maxlen - 1);
	return c;
}

/**
 * Reads a value stored in a memory address and returns it as an address.
 * This currently assumes a 32-bit platform.
 * 
 * @param addr			Address to a memory location.
 * @return				The value stored in the given address as an Address.
 */
stock Address DereferencePointer(Address addr) {
	// maybe someday we'll do 64-bit addresses
	return view_as<Address>(LoadFromAddress(addr, NumberType_Int32));
}

/**
 * Retrieves an entity index from a raw entity handle address.
 * 
 * Note that SourceMod's entity conversion routine is an implementation detail that may change.
 * 
 * @param addr			Address to a memory location.
 * @return				Entity index, or -1 if not valid.
 */
stock int LoadEntityHandleFromAddress(Address addr) {
	return EntRefToEntIndex(LoadFromAddress(addr, NumberType_Int32) | (1 << 31));
}

/**
 * Stores an entity into a raw entity handle address.  Stores zero if the entity is not valid.
 * 
 * Note that SourceMod's entity conversion routine is an implementation detail that may change.
 * 
 * @param addr			Address to a memory location.
 * @param entity		Entity index.
 */
stock void StoreEntityHandleToAddress(Address addr, int entity) {
	StoreToAddress(addr, IsValidEntity(entity)? EntIndexToEntRef(entity) & ~(1 << 31) : 0,
			NumberType_Int32);
}

/**
 * Returns an entity index from its address by attempting to read the
 * CBaseEntity::m_RefEHandle member.  This assumes the address of a CBaseEntity is
 * passed in.
 * 
 * @param pEntity		Address of an entity.
 * @return				Entity index, or -1 if not valid.
 */
stock int GetEntityFromAddress(Address pEntity) {
	static int offs_RefEHandle;
	if (offs_RefEHandle) {
		return LoadEntityHandleFromAddress(pEntity + view_as<Address>(offs_RefEHandle));
	}
	
	// if we don't have it already, attempt to lookup offset based on SDK information
	// CWorld is derived from CBaseEntity so it should have both offsets
	int offs_angRotation = FindDataMapInfo(0, "m_angRotation"),
			offs_vecViewOffset = FindDataMapInfo(0, "m_vecViewOffset");
	if (offs_angRotation == -1) {
		ThrowError("Could not find offset for ((CBaseEntity) CWorld)::m_angRotation");
	} else if (offs_vecViewOffset == -1) {
		ThrowError("Could not find offset for ((CBaseEntity) CWorld)::m_vecViewOffset");
	} else if ((offs_angRotation + 0x0C) != (offs_vecViewOffset - 0x04)) {
		char game[32];
		GetGameFolderName(game, sizeof(game));
		ThrowError("Could not confirm offset of CBaseEntity::m_RefEHandle "
				... "(incorrect assumption for game '%s'?)", game);
	}
	
	// offset seems right, cache it for the next call
	offs_RefEHandle = offs_angRotation + 0x0C;
	return GetEntityFromAddress(pEntity);
}
