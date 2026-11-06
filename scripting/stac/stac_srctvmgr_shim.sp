/*
    SourceTV manager shim
    =====================

    First-party reimplementation of the three sourcetvmanager natives StAC consumes:

        SourceTV_IsRecording        -> Stac_SrcTV_IsRecording
        SourceTV_GetRecordingTick   -> Stac_SrcTV_GetRecordingTick
        SourceTV_GetDemoFileName    -> Stac_SrcTV_GetDemoFileName

    Lets us drop the external sourcetvmanager extension dependency.

    --------------------------------------------------------------------------
    Engine path on linux x86 (RE'd against TF2 engine_srv.so, 2026-05-09):

        1. Global `hltv` is a `CHLTVServer*` variable in engine.

            CHLTVDemoRecorder::StartAutoRecording references it directly:

                .text:0012F67D     mov     eax, ds:hltv     ; A1 1C BD 33 00

            The `A1` opcode is one byte at func+0x1D, and the imm32 that follows
            (i.e. the address of the `hltv` variable itself) sits at func+0x1E
            (= 30 decimal). We use that as a sig+read anchor in gamedata.

        2. m_DemoRecorder is a CHLTVDemoRecorder field embedded inside CHLTVServer.

            Confirmed in CHLTVServer::Shutdown:

                .text:0013651A     lea     eax, [ebx+4DD4h]
                .text:00136520     push    eax              ; this
                .text:00136521     call    _ZN17CHLTVDemoRecorder13StopRecordingEv

            => m_DemoRecorder lives at offset 0x4DD4 (19924) inside CHLTVServer.

        3. CDemoFile lives at offset +4 within CHLTVDemoRecorder (right after the
            vtable pointer). Confirmed in CHLTVDemoRecorder::StartRecording:

                .text:001300B2     lea     esi, [ebx+4]
                .text:001300C2     call    _ZN9CDemoFile4OpenEPKcbbib

            The first member of CDemoFile is `char m_szFileName[MAX_OSPATH]`, so
            `recorder + m_DemoFile_offset` is also the C-string of the demo path.

            This matches what the original ext does for non-CSGO engines:

                // sourcetvmanager/hltvserverwrapper.cpp::GetDemoFileName
                return (char *)m_DemoRecorder->GetDemoFile();

            where GetDemoFile() is an inlined `return this + 4` leaf (verified at
            _ZN17CHLTVDemoRecorder11GetDemoFileEv @ 0x12F100, 11 bytes).

        4. CHLTVDemoRecorder's vtable matches the IDemoRecorder header order
            (sourcetvmanager/ihltvdemorecorder.h) exactly — IDemoRecorder has no
            virtual dtor, so derived dtors are appended at the end. Confirmed via
            data refs in the .data.rel.ro vtable at 0x22A750:

                slot  function                    ptr (engine_srv.so x86)
                ----  --------------------------  ------------------------
                0     GetDemoFile                 0x12F100  (returns this+4)
                1     GetRecordingTick            0x12F110
                2     StartRecording              0x130080
                3     SetSignonState              0x130480  (empty stub)
                4     IsRecording                 0x12F0F0  (return this[0x540])
                5     PauseRecording              0x130490  (empty stub)
                6     ResumeRecording             0x1304A0  (empty stub)
                7     StopRecording               0x12F410
                8     RecordCommand               0x12F4A0
                9     RecordUserInput             0x1304B0
                10    RecordMessages              0x12F130
                11    RecordPacket                0x12F8C0
                12    RecordServerClasses         0x12F1B0
                13    RecordStringTables          0x12F530
                14    ResetDemoInterpolation      0x1304C0  (empty stub)
                15    ~CHLTVDemoRecorder D2       0x12F430
                16    ~CHLTVDemoRecorder D0       0x12F460

    --------------------------------------------------------------------------
    Engine path on linux x64 (RE'd against TF2 engine_srv.so x64, 2026-05-09):

        1. Global `hltv` (CHLTVServer*) is at engine_srv.so!0x369670. Same
            anchor function as linux x86 (CHLTVDemoRecorder::StartAutoRecording
            @ 0x10B320), but the encoding is different because x64 binaries
            use position-independent code:

                .text:0010B349   48 8D 05 <disp32>   lea rax, hltv

            The 7-byte LEA puts a 32-bit RIP-relative displacement at func+0x2C
            (= 44 decimal), and `&hltv = (LEA_end) + disp32` where `LEA_end =
            func + 0x30 = disp32_ptr + 4`.

            SourceMod's sig+`read N` mechanism can't parse this directly --
            a `read 44` would try to dereference the 8 bytes starting at the
            disp32, which on x64 spans into the next instruction's bytes. So
            the gamedata uses `offset 44` (sigMatch + 44, no deref) and the
            shim resolves &hltv in plugin code via:

                int  disp32 = LoadFromAddress(disp32_ptr, NumberType_Int32);
                &hltv       = (disp32_ptr + 4) + disp32;     // signed 32-bit add

            Sanity: 0x10B350 + 0x25E320 = 0x369670 (live values verified).

        2. m_DemoRecorder offset = 0x8E78 = 36472. Four independent witnesses
            in the same binary all use the same `lea reg, [hltv + 0x8E78]`:

            a) tv_stoprecord ConCommand callback @ 0x1113E0 dispatches
                StopRecording((char*)hltv + 36472)
            b/c/d) tv_status @ 0x112F90 dispatches three IDemoRecorder
                virtuals in a row, each with `lea rdi, [rax+8E78h]`
                (rax = hltv loaded via cs:hltv RIP-relative), at .text
                offsets 0x113382 (IsRecording) / 0x1133B1 (GetRecordingTick)
                / 0x1133E0 (GetDemoFile). Note: gcc devirtualised these
                sites to direct calls -- the offset is still the right one
                to use against an indirect IDemoRecorder*.

            The (very nearly) 2x scaling vs linux x86 (19924 -> 36472) is
            the standard "x86 -> x64 widens vtable + fundamental field
            sizes" effect on the parent CBaseServer layout.

        3. m_DemoFile offset = 8 (vs 4 on x86 -- vtable pointer doubled).
            CHLTVDemoRecorder::GetDemoFile @ 0x10AD50 has the entire body
            compiled to a leaf:

                __int64 GetDemoFile(CHLTVDemoRecorder *this) {
                return (__int64)this + 8;
                }

            Cross-confirmed by CHLTVDemoRecorder::StartRecording @ 0x10BDE0
            calling CDemoFile::Open((char*)this + 8, ...).

        4. CHLTVDemoRecorder vtable layout matches the x86 builds verbatim
            (the IDemoRecorder header has no virtual dtor on any known TF2
            build, so slots stay header-pinned). Verified by cross-referencing
            the three IDemoRecorder leaf functions against `.data.rel.ro`:
            their data-xref slots are 8 bytes apart with the IsRecording slot
            exactly four 8-byte slots past GetDemoFile, i.e. slot indices
            0 / 1 / 4 for GetDemoFile / GetRecordingTick / IsRecording.

    --------------------------------------------------------------------------
    Engine path on windows x86 (RE'd against TF2 engine.dll, 2026-05-09):

        1. Global `hltv` (CHLTVServer*) is at engine.dll!0x10635664. Anchor:
            the ConCommand callback for `tv_stoprecord` (we named it
            `tv_stoprecord_f` to follow Source's internal naming convention;
            it has no public/exported symbol). 0x3B-byte function whose first
            instruction is

                .text:1017F7E0    8B 0D <imm32>     mov     ecx, &hltv

            so a sigscan + `read 2` lands on the 4 bytes containing `&hltv`.
            Full disasm + the makesig.py-generated SourceMod signature live in
            gamedata/stac.txt under "tv_stoprecord_f".

        2. m_DemoRecorder offset = 0x4DF0 = 19952. Two independent witnesses
            in the same binary agree:

            a) tv_stoprecord_f itself does
                    mov  eax, [ecx+4DF0h]
                    lea  ecx, [ecx+4DF0h]
                with ecx == &hltv. Those 6-byte instructions are baked into
                the un-wildcarded portion of the gamedata signature, so an
                audit can directly compare the `\x8B\x81\xF0\x4D\x00\x00`
                bytes at the end of the sig against this offset entry.

            b) tv_status_f @ 0x1017F480 dispatches recorder->IsRecording()
                via *(dword_10635664 + 19952), again confirming the offset.

            The 28-byte gap vs the linux x86 offset (0x4DD4 -> 0x4DF0) is
            entirely accounted for by MSVC's slightly different CBaseServer
            layout — the field's logical position is the same.

        3. m_DemoFile offset = 4. CHLTVDemoRecorder::StartRecording @
            0x1017A950 has

                .text:1017A966    lea     ecx, [esi+4]            ; this == CDemoFile*
                .text:1017A972    call    sub_100CC660            ; CDemoFile::Open

            (esi is the recorder `this`; +4 skips the 32-bit vtable pointer.)

        4. CHLTVDemoRecorder vtable layout matches the linux build verbatim
            (header-only abstract base => slot order is header-pinned). Engine
            confirms by dispatching IsRecording / GetRecordingTick at the same
            slot indices in tv_status_f's pseudocode.

    --------------------------------------------------------------------------
    Engine path on windows x64 (RE'd against TF2 engine.dll x64, 2026-05-10):

        1. Global `hltv` (CHLTVServer*) is at engine.dll!0x180752B20. Same
            anchor strategy as windows x86 -- the static `tv_stoprecord`
            ConCommand callback (which we name `tv_stoprecord_f` to match
            Source's internal naming convention) -- but with x64-style
            RIP-relative addressing.

            engine.dll x64 sub_18019EC00 (0x4D-byte function):

                18019EC00  48 83 EC 28           sub  rsp, 28h
                18019EC04  48 8B 0D <disp32>     mov  rcx, &hltv     ; 7 bytes
                18019EC0B  48 85 C9              test rcx, rcx
                ... hltv-null bail / IServer::IsActive guard ...
                18019EC22  48 8B 0D <disp32>     mov  rcx, &hltv
                18019EC29  48 81 C1 78 8E 00 00  add  rcx, 8E78h     ; <-- m_DemoRecorder offset
                18019EC30  48 8B 01              mov  rax, [rcx]
                18019EC33  48 83 C4 28           add  rsp, 28h
                18019EC37  48 FF 60 38           jmp  qword ptr [rax+38h] ; vtable[7] = StopRecording

            The 4-byte prologue + 3-byte `48 8B 0D` REX+opcode+ModRM puts the
            disp32 at func+7. SourceMod's "CHLTVServer*_x64_disp32" entry uses
            `offset 7` so it returns sigMatch+7 (= disp32_ptr) without
            dereferencing; the shim's init code then resolves
            &hltv = (disp32_ptr + 4) + disp32 in plugin code.

            Sanity: 0x18019EC0B + 0x005B3F15 = 0x180752B20 (live values
            verified).

        2. m_DemoRecorder offset = 0x8E78 = 36472 (identical to linux x64).
            The signature for tv_stoprecord_f leaves the literal `78 8E 00 00`
            un-wildcarded for cross-checking, and tv_status (sub_18019E760)
            provides three additional witnesses (IsRecording / GetRecordingTick
            / GetDemoFile call sites all dispatch off `qword_180752B20 + 36472`).

            The fact that windows x64 and linux x64 agree exactly on this
            offset (vs the 28-byte gap on x86) is the standard "x64 ABIs
            have settled on the same fundamental sizes / packing rules"
            outcome for CBaseServer-derived layouts.

        3. m_DemoFile offset = 8 (identical to linux x64). Confirmed in
            CHLTVDemoRecorder::StartRecording (sub_180198A50):

                if ( sub_1800BE1C0((int)a1 + 8, ...) )   ; CDemoFile::Open
                    ConMsg("Recording SourceTV demo to %s...\n", a2);

            (The `(int)` cast is an IDA decompile artefact -- RCX carries the
            full 64-bit recorder pointer.)

        4. CHLTVDemoRecorder vtable layout matches every other platform
            verbatim. Confirmed by the engine itself dispatching IsRecording
            / GetRecordingTick / GetDemoFile through vtable byte offsets
            32 / 8 / 0 inside the tv_status decompile (i.e. slot indices
            4 / 1 / 0 with x64's 8-byte slot stride).

    --------------------------------------------------------------------------
    Platform support status:

        linux       - filled in (engine_srv.so x86, 2026-05-09)
        windows     - filled in (engine.dll    x86, 2026-05-09)
        linux64     - filled in (engine_srv.so x64, 2026-05-10)
        windows64   - filled in (engine.dll    x64, 2026-05-10)

    On platforms with missing gamedata, the shim disables itself and the
    StacLog calls below explain what's missing. StAC's demo-name-in-banreason
    feature degrades to "N/A" and life goes on.

    Recipe to fill in another platform:

        a) Find any function that reads the global CHLTVServer pointer/instance.
            StartAutoRecording is convenient on linux (both bitnesses);
            tv_stoprecord_f is convenient on windows x86 because its first
            instruction loads `&hltv` into a register.

            On x86 you're looking for a `mov reg, ds:hltv` (`A1 ...` /
            `8B 0D <imm32>`) or similar -- the imm32 IS &hltv, and a
            sigscan + `read N` (where N is the byte offset of the imm32
            inside the function) hands &hltv straight back. Put that under
            "CHLTVServer*".

            On x64 you're looking for a `mov reg, cs:hltv` or `lea reg,
            [rip+disp32]` (`48 8B 05 <disp32>` / `48 8D 05 <disp32>`) -- the
            disp32 is RIP-relative and SM's `read N` cannot decode it. Use
            `offset N` (where N is the byte offset of the disp32 inside the
            function) so SM returns sigMatch+N WITHOUT dereferencing, and put
            that under "CHLTVServer*_x64_disp32". The shim's init code already
            knows to fall back to that key and resolve &hltv via
            (disp32_ptr + 4) + disp32. For windows64 specifically, watch out
            for compilers that fully inline the load -- in that case anchor
            on a small ConCommand callback like tv_stoprecord that's almost
            guaranteed to keep the load explicit.

        b) Disassemble CHLTVServer::Shutdown — the first body call is
            CHLTVDemoRecorder::StopRecording((char*)this + N). N is the
            m_DemoRecorder offset. (You can also confirm by decompiling
            tv_status_f / tv_stoprecord_f and finding the same constant.)

        c) Disassemble CHLTVDemoRecorder::StartRecording — early on it does
            `lea reg, [this + M]` then calls a CDemoFile method. M is the
            CDemoFile offset (= the m_DemoFile_offset).

        d) Confirm vtable layout vs ihltvdemorecorder.h. If the binary is built
            with a virtual dtor in IDemoRecorder, slots shift; in that case
            update IDemoRecorder::IsRecording / GetRecordingTick / GetDemoFile
            offsets accordingly. As of all known TF2 builds the header has no
            virtual dtor, so all four platforms share slot indices 4 / 1 / 0.

        e) On x64, dereferencing the global pointer needs LoadAddressFromAddress
            (which reads sizeof(void*) bytes) — the SP code below already uses
            it, so no plugin changes required, just gamedata.

        f) Generate the SourceMod-format signature with
            D:\IDA\IDA-Scripts\makesig.py
            (cursor on the function entry, run as a script). It emits a
            `\x..` byte string with `\x2A` for wildcards, ready to paste into
            "Signatures" -- see "tv_stoprecord_f" in stac.txt for the format.
            (Skip this on linux; the mangled symbol from the .so is enough.)

        g) Use `sm_stac_test_srctv` to verify everything end-to-end on a live
            server. The diagnostic prints every gamedata value, every pointer
            it dereferences, the recorder vtable address, and round-trips the
            SDKCalls -- so any single bad gamedata entry shows up immediately.
*/

#pragma semicolon 1

// Address OF the global `hltv` variable inside the engine module. To get the
// actual CHLTVServer* instance, dereference via LoadAddressFromAddress.
//
// NOTE: not initialised here — SM 1.13 widened Address to int64 and int64
// values aren't constant-expression-initialisable at file scope. We zero it
// in StacSrcTVShim_Init below.
static Address  g_srctv_HltvSymbolAddr;

// Bytes from a CHLTVServer* to its embedded CHLTVDemoRecorder field.
static int      g_srctv_DemoRecorderOffset;

// Bytes from a CHLTVDemoRecorder* to its embedded CDemoFile (whose first
// member is the m_szFileName buffer).
static int      g_srctv_DemoFileOffset;

// SDKCalls bound to IDemoRecorder vtable slots.
static Handle   g_srctv_SDKCall_IsRecording        = INVALID_HANDLE;
static Handle   g_srctv_SDKCall_GetRecordingTick   = INVALID_HANDLE;

// True iff every gamedata lookup + SDKCall bind succeeded.
static bool     g_srctv_ready                      = false;

// Diagnostic-only: which resolution path produced g_srctv_HltvSymbolAddr.
// "direct"  -> sig + read N landed on &hltv directly (32-bit builds)
// "rip"     -> sig + offset N landed on a disp32 inside a RIP-relative
//              LEA, and we resolved &hltv = (disp_ptr + 4) + disp32 in SP
// ""        -> not yet resolved
static char     g_srctv_HltvResolveMethod[16];

// Diagnostic-only state populated when the rip path is taken: the address
// SourceMod handed us (= a pointer to the disp32 bytes) and the disp32
// value we read out of it.
static Address  g_srctv_HltvRipDispPtr;
static int      g_srctv_HltvRipDispVal;


void StacSrcTVShim_Init()
{
    g_srctv_ready                  = false;
    g_srctv_HltvSymbolAddr         = Address_Null;
    g_srctv_DemoRecorderOffset     = 0x0;
    g_srctv_DemoFileOffset         = 0x0;
    g_srctv_HltvResolveMethod[0]   = 0x0;
    g_srctv_HltvRipDispPtr         = Address_Null;
    g_srctv_HltvRipDispVal         = 0x0;

    if (stac_gamedata == null)
    {
        // DoStACGamedata SetFailState'd already; nothing to do.
        return;
    }

    // Path 1: direct lookup via gamedata's "CHLTVServer*" key. Used on
    // 32-bit builds where the engine encodes &hltv as a plain imm32 inside
    // a `mov reg, &hltv`. SourceMod's sig+`read N` decodes that for us.
    g_srctv_HltvSymbolAddr = GameConfGetAddress(stac_gamedata, "CHLTVServer*");
    if (g_srctv_HltvSymbolAddr != Address_Null)
    {
        strcopy(g_srctv_HltvResolveMethod, sizeof(g_srctv_HltvResolveMethod), "direct");
    }
    else
    {
        // Path 2: x64 fallback. On RIP-relative builds the sig+`offset N`
        // entry under "CHLTVServer*_x64_disp32" hands us a pointer to the
        // 4 disp32 bytes inside a `lea reg, [rip+disp32]` (or equivalent
        // mov-from-RIP). The 32-bit SIGNED disp32 plus the RIP at end of
        // the instruction (= disp_ptr + 4) gives us &hltv.
        g_srctv_HltvRipDispPtr = GameConfGetAddress(stac_gamedata, "CHLTVServer*_x64_disp32");
        if (g_srctv_HltvRipDispPtr == Address_Null)
        {
            StacLog("[srctv-shim] gamedata is missing both CHLTVServer* and CHLTVServer*_x64_disp32 for this OS; demo info unavailable.");
            return;
        }

        // LoadFromAddress with NumberType_Int32 returns a signed 32-bit
        // SourcePawn cell. Adding it directly to an Address (int64) lets
        // SP's normal int -> int64 promotion sign-extend the negative
        // case correctly, which is what we need for forward and backward
        // references alike.
        g_srctv_HltvRipDispVal = LoadFromAddress(g_srctv_HltvRipDispPtr, NumberType_Int32);
        g_srctv_HltvSymbolAddr = g_srctv_HltvRipDispPtr + view_as<Address>(4) + g_srctv_HltvRipDispVal;

        strcopy(g_srctv_HltvResolveMethod, sizeof(g_srctv_HltvResolveMethod), "rip");
    }

    g_srctv_DemoRecorderOffset = GameConfGetOffset(stac_gamedata, "CHLTVServer::m_DemoRecorder");
    if (g_srctv_DemoRecorderOffset <= 0)
    {
        StacLog("[srctv-shim] gamedata is missing the CHLTVServer::m_DemoRecorder offset for this OS; demo info unavailable.");
        return;
    }

    g_srctv_DemoFileOffset = GameConfGetOffset(stac_gamedata, "CHLTVDemoRecorder::m_DemoFile");
    if (g_srctv_DemoFileOffset <= 0)
    {
        StacLog("[srctv-shim] gamedata is missing the CHLTVDemoRecorder::m_DemoFile offset for this OS; demo info unavailable.");
        return;
    }

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(stac_gamedata, SDKConf_Virtual, "IDemoRecorder::IsRecording");
    PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
    g_srctv_SDKCall_IsRecording = EndPrepSDKCall();
    if (g_srctv_SDKCall_IsRecording == INVALID_HANDLE)
    {
        StacLog("[srctv-shim] failed to bind IDemoRecorder::IsRecording vtable slot; demo info unavailable.");
        return;
    }

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(stac_gamedata, SDKConf_Virtual, "IDemoRecorder::GetRecordingTick");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_srctv_SDKCall_GetRecordingTick = EndPrepSDKCall();
    if (g_srctv_SDKCall_GetRecordingTick == INVALID_HANDLE)
    {
        StacLog("[srctv-shim] failed to bind IDemoRecorder::GetRecordingTick vtable slot; demo info unavailable.");
        return;
    }

    g_srctv_ready = true;
    StacLog
    (
        "[StAC] SourceTV shim ready (resolve=%s, m_DemoRecorder=+0x%X, m_DemoFile=+0x%X).",
        g_srctv_HltvResolveMethod,
        g_srctv_DemoRecorderOffset,
        g_srctv_DemoFileOffset
    );
}

// Returns the address of the embedded CHLTVDemoRecorder field (which is also
// the IDemoRecorder pointer used by virtual calls), or Address_Null if
// SourceTV is disabled or the shim isn't ready.
static Address StacSrcTVShim_GetRecorder()
{
    if (!g_srctv_ready)
    {
        return Address_Null;
    }

    Address chltvServer = LoadAddressFromAddress(g_srctv_HltvSymbolAddr);
    if (chltvServer == Address_Null)
    {
        return Address_Null;
    }

    return chltvServer + view_as<Address>(g_srctv_DemoRecorderOffset);
}


bool Stac_SrcTV_IsRecording()
{
    Address recorder = StacSrcTVShim_GetRecorder();
    if (recorder == Address_Null)
    {
        return false;
    }
    return view_as<bool>( SDKCall(g_srctv_SDKCall_IsRecording, recorder) );
}


int Stac_SrcTV_GetRecordingTick()
{
    Address recorder = StacSrcTVShim_GetRecorder();
    if (recorder == Address_Null)
    {
        return -1;
    }
    if (!Stac_SrcTV_IsRecording())
    {
        return -1;
    }
    return SDKCall(g_srctv_SDKCall_GetRecordingTick, recorder);
}

bool Stac_SrcTV_GetDemoFileName(char[] buf, int maxlen)
{
    if (maxlen <= 0)
    {
        return false;
    }
    buf[0] = 0x0;

    if (!Stac_SrcTV_IsRecording())
    {
        return false;
    }

    Address recorder = StacSrcTVShim_GetRecorder();
    if (recorder == Address_Null)
    {
        return false;
    }

    Address namePtr = recorder + view_as<Address>(g_srctv_DemoFileOffset);

    // Manual strcpy out of engine memory: namePtr points at the first byte
    // of CDemoFile::m_szFileName (a fixed-size char[MAX_OSPATH] embedded in
    // the recorder), and SourcePawn has no "read C string from address"
    // native -- only LoadFromAddress, which does one numeric read at a
    // time. So we walk one byte at a time, stop at the NUL terminator, and
    // bail out early if our caller-supplied buffer fills up first. The
    // `& 0xFF` mask defends against LoadFromAddress sign-extending a high
    // byte (>= 0x80) into a negative cell, which would never compare equal
    // to 0 and would also poison the destination char.
    int i;
    int last = maxlen - 1;
    for (i = 0; i < last; i++)
    {
        int c = LoadFromAddress(namePtr + view_as<Address>(i), NumberType_Int8) & 0xFF;
        if (c == 0x0)
        {
            break;
        }
        buf[i] = c;
    }
    buf[i] = 0x0;
    return i > 0;
}


// Walks the whole shim chain end-to-end and prints what it sees to the
// calling admin's console (or the server console when invoked from RCON).
// Intended to be invoked from the `sm_stac_test_srctv` admin command. Safe
// to call any time after StacSrcTVShim_Init has run, including when
// SourceTV is off.
//
// Output is batched into as few PrintToConsole calls as possible (each kept
// well under the 1024-byte SourceMod cap) so that ordered lines stay
// together client-side -- consecutive PrintToConsole calls aren't
// guaranteed to render in order on in-game consoles when other game traffic
// interleaves.
void Stac_SrcTV_DumpDiagnostics(int callingCl)
{
    if (callingCl != 0)
    {
        ReplyToCommand(callingCl, "[StAC] Check your console!");
    }

    // Build a small "resolution path" trailer line that's shared across all
    // three output paths below. On x64 / RIP-relative builds it tells you
    // which gamedata key was used and what the in-instruction disp32 was,
    // which is exactly what you'd want to cross-check against IDA when a
    // server update breaks the anchor function. On x86 / direct builds it's
    // a single short line so the dump still names the resolution mechanism.
    char resolveLine[160];
    if (StrEqual(g_srctv_HltvResolveMethod, "rip"))
    {
        FormatEx
        (
            resolveLine, sizeof(resolveLine),
            "  &hltv resolution                   : rip-relative @ disp_ptr=0x%lx, disp32=%d (0x%X)\n",
            g_srctv_HltvRipDispPtr,
            g_srctv_HltvRipDispVal,
            g_srctv_HltvRipDispVal
        );
    }
    else
    {
        FormatEx
        (
            resolveLine, sizeof(resolveLine),
            "  &hltv resolution                   : %s\n",
            g_srctv_HltvResolveMethod[0] ? g_srctv_HltvResolveMethod : "(none -- shim not ready)"
        );
    }

    // Path 1: shim never initialized (gamedata key missing for this OS).
    if (!g_srctv_ready)
    {
        PrintToConsole
        (
            callingCl,
            "\
[StAC] === SourceTV shim diagnostic ===\n\
-- gamedata --\n\
  shim ready                         : NO (check earlier StAC log entries for which key was missing for this OS)\n\
%s\
  &hltv  (engine global var address) : 0x%lx\n\
  m_DemoRecorder offset (CHLTVServer): 0x%X (%d)\n\
  m_DemoFile     offset (recorder)   : 0x%X (%d)\n\
(shim not ready -- aborting runtime test)\n\
=== END ===",
            resolveLine,
            g_srctv_HltvSymbolAddr,
            g_srctv_DemoRecorderOffset, g_srctv_DemoRecorderOffset,
            g_srctv_DemoFileOffset,     g_srctv_DemoFileOffset
        );
        return;
    }

    Address chltvServer = LoadAddressFromAddress(g_srctv_HltvSymbolAddr);

    // Path 2: shim ready, but SourceTV is currently off (no CHLTVServer).
    if (chltvServer == Address_Null)
    {
        PrintToConsole
        (
            callingCl,
            "\
[StAC] === SourceTV shim diagnostic ===\n\
-- gamedata --\n\
  shim ready                         : YES\n\
%s\
  &hltv  (engine global var address) : 0x%lx\n\
  m_DemoRecorder offset (CHLTVServer): 0x%X (%d)\n\
  m_DemoFile     offset (recorder)   : 0x%X (%d)\n\
-- runtime pointer chase --\n\
  *(&hltv)         CHLTVServer*      : 0x0\n\
(hltv is NULL -- SourceTV is disabled. Set 'tv_enable 1' in server.cfg\n\
 and 'changelevel <map>' to bring CHLTVServer up, then re-run this command.)\n\
=== END ===",
            resolveLine,
            g_srctv_HltvSymbolAddr,
            g_srctv_DemoRecorderOffset, g_srctv_DemoRecorderOffset,
            g_srctv_DemoFileOffset,     g_srctv_DemoFileOffset
        );
        return;
    }

    // Path 3: shim ready and SourceTV is up. Resolve the rest of the chain
    // and exercise the SDKCalls / public API.
    Address recorder       = chltvServer + view_as<Address>(g_srctv_DemoRecorderOffset);
    Address recorderVtable = LoadAddressFromAddress(recorder);
    Address demoFilePtr    = recorder + view_as<Address>(g_srctv_DemoFileOffset);

    bool isRec = view_as<bool>( SDKCall(g_srctv_SDKCall_IsRecording, recorder) );
    int  tick  = SDKCall(g_srctv_SDKCall_GetRecordingTick, recorder);

    char fname[PLATFORM_MAX_PATH];
    bool fnameOk = Stac_SrcTV_GetDemoFileName(fname, sizeof(fname));

    // Block 1/2: header + gamedata + pointer chase. ~800 bytes worst case.
    PrintToConsole
    (
        callingCl,
        "\
[StAC] === SourceTV shim diagnostic ===\n\
-- gamedata --\n\
  shim ready                         : YES\n\
%s\
  &hltv  (engine global var address) : 0x%lx\n\
  m_DemoRecorder offset (CHLTVServer): 0x%X (%d)\n\
  m_DemoFile     offset (recorder)   : 0x%X (%d)\n\
-- runtime pointer chase --\n\
  *(&hltv)         CHLTVServer*      : 0x%lx\n\
  chltv + 0x%X   CHLTVDemoRecorder*: 0x%lx\n\
  *recorder        vtable            : 0x%lx\n\
                                       (cross-check vs IDA: should land in .data.rel.ro,\n\
                                        pointing at slot 0 of CHLTVDemoRecorder vtable)\n\
  recorder + 0x%X  CDemoFile*        : 0x%lx",
        resolveLine,
        g_srctv_HltvSymbolAddr,
        g_srctv_DemoRecorderOffset, g_srctv_DemoRecorderOffset,
        g_srctv_DemoFileOffset,     g_srctv_DemoFileOffset,
        chltvServer,
        g_srctv_DemoRecorderOffset, recorder,
        recorderVtable,
        g_srctv_DemoFileOffset,     demoFilePtr
    );

    // Block 2/2: SDKCall round-trip + public API + END (+ optional
    // not-recording hint). ~600 bytes worst case (longer with PLATFORM_MAX_PATH-sized demo name).
    PrintToConsole
    (
        callingCl,
        "\
-- SDKCall round-trip (real engine virtual calls) --\n\
  IDemoRecorder::IsRecording()       : %s\n\
  IDemoRecorder::GetRecordingTick()  : %d\n\
-- public shim API --\n\
  Stac_SrcTV_IsRecording()           : %s\n\
  Stac_SrcTV_GetRecordingTick()      : %d\n\
  Stac_SrcTV_GetDemoFileName() ok    : %s\n\
  Stac_SrcTV_GetDemoFileName() name  : \"%s\"%s\n\
=== END ===",
        isRec   ? "true" : "false",
        tick,
        Stac_SrcTV_IsRecording()      ? "true" : "false",
        Stac_SrcTV_GetRecordingTick(),
        fnameOk ? "true" : "false",
        fname,
        isRec ? "" : "\n(not currently recording -- run 'tv_record <name>' on the\nserver console and re-run this command to verify the demo path lookup)"
    );
}
