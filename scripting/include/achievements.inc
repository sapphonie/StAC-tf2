/** 
 * A list of achievements in Team Fortress 2 based on achievement ID.
 * 
 * Sourced from https://wiki.alliedmods.net/Achievement_IDs and gratuitous abuse of the
 * "achievement_earned" event, plus a good amount of typing saved by letting Python format the
 * language entries into enum values (converting SNAKE_CASE to TitleCase and adding the English
 * achievement name as a comment next to it).
 */

#if defined __stocksoup_tf_enum_achievements_included
	#endinput
#endif

#define __stocksoup_tf_enum_achievements_included

/* This list should be current as of the Meet Your Match update (2016/07/07). */

enum TFAchievements {
	// 100: General Achievements
	Achievement_GetTurretKills = 127, // Sentry Gunner
	Achievement_KillNemesis, // Nemesis
	Achievement_GetConsecutiveKillsNoDeaths, // Hard to Kill
	Achievement_GetHealedByEnemy, // Master of Disguise (130)
	Achievement_PlayGameFriendsOnly, // With Friends Like these...
	Achievement_WinMultipleGames, // Dynasty
	Achievement_GetMultipleKills, // Hardcore
	Achievement_Win2fortNoEnemyCaps, // Powerhouse Offense
	Achievement_WinWellMinimumTime, // Lightning Offense
	Achievement_WinHydroNoEnemyCaps, // Relentless Offense
	Achievement_WinDustbowlNoEnemyCaps, // Impenetrable Defense
	Achievement_WinGravelPitNoEnemyCaps, // Impossible Defense
	Achievement_PlayGameEveryClass, // Head of the Class
	Achievement_PlayGameEveryMap, // World Traveler (140)
	Achievement_GetHealPoints, // Team Doctor
	Achievement_BurnPlayersInMinimumTime, // Flamethrower
	
	Achievement_GetHeadshots = 145, // Grey Matter
	
	Achievement_GeneralKillEnemiesAfterTeleporting = 150, // Riftwalker (150)
	Achievement_CompleteTraining, // Ready for Duty
	Achievement_FireWaterJump, // Escape the Heat
	Achievement_KillBalloonicornOwners, // The Great Deflate
	Achievement_MultipleBFF, // BFF
	Achievement_TeamPyrovision, // Mass Hysteria
	Achievement_DominateForGoggles, // A Fresh Pair of Eyes
	Achievement_ParachuteKillGrind, // Nose Dive
	Achievement_MeleeKillClassicRifleSniper, // Punching Bag
	Achievement_KillChargingDemo, // Emergency Brake
	Achievement_TauntCongaKill, // Party Crasher (160)
	Achievement_TauntCongaLine, // Conga Line
	Achievement_TauntRPSRock, // On The Rocks
	Achievement_TauntRPSScissors, // Running With Scissors
	Achievement_TauntDosidoMeleeKill, // May I Cut In, Too?
	Achievement_TauntWhileCapping, // Showboat
	Achievement_PassTimeHat, // Tune Merasmus's Multi-Dimensional Television
	Achievement_PassTimeGrind, // Jackpot! (167)
	
	
	// 1000: Scout Achievements
	Achievement_ScoutFirstBlood = 1001, // First Blood
	Achievement_ScoutFirstBloodKill, // First Blood, Part 2
	Achievement_ScoutWellEarlyKill, // Quick Hook
	Achievement_ScoutLifetimeKills, // A Year to Remember
	Achievement_ScoutIronManKills, // The Cycle
	Achievement_ScoutDestroyTeleporters, // Closer
	Achievement_ScoutDestroyBuildingsBeingBuilt, // If You Build It
	Achievement_ScoutDestroySentryWithPistol, // Gun Down
	Achievement_ScoutDoubleJumps, // Batter Up
	Achievement_ScoutAssistMedic, // Doctoring the Ball (1010)
	Achievement_ScoutStealSandwich, // Dodgers 1, Giants 0
	Achievement_ScoutKillChargedMedics, // Batting the Doctor
	Achievement_ScoutSurviveDamage, // I'm Bat Man
	Achievement_ScoutThreeFlagCaps, // Triple Steal
	Achievement_ScoutDoubleJumpKill, // Pop Fly
	Achievement_ScoutFlagCapGrind, // Round-Tripper
	Achievement_ScoutDodgeDamage, // Artful Dodger
	Achievement_ScoutKnockIntoTrain, // Fall Classic
	Achievement_ScoutKillStunned, // Strike Zone
	Achievement_ScoutStunIntoTrain, // Foul Territory (1020)
	Achievement_ScoutStunUberEnemies, // The Big Hurt
	Achievement_ScoutStunCappingEnemies, // Brushback
	Achievement_ScoutMaxStuns, // Moon Shot
	Achievement_ScoutStunScoutWithTheirBall, // Beanball
	Achievement_ScoutKillInDodgeCooldown, // Retire the Runner
	Achievement_ScoutKillFromBehind, // Caught Napping
	Achievement_ScoutCaptureLastPoint, // Side Retired
	Achievement_ScoutCaptureThreePoints, // Triple Play
	Achievement_ScoutFastCap, // Stealing Home
	Achievement_ScoutStartAndFinishCap, // Set the Table (1030)
	Achievement_ScoutBlockCaps, // Block the Plate
	Achievement_ScoutCarrierKillCarrier, // Belittled Beleaguer
	Achievement_ScoutCapFlagWithoutAttacking, // No-Hitter
	Achievement_ScoutLongDistanceRunner, // Race for the Pennant
	Achievement_ScoutTauntKill, // Out of the Park
	Achievement_ScoutAchieveProgress1, // Scout Milestone 1
	Achievement_ScoutAchieveProgress2, // Scout Milestone 2
	Achievement_ScoutAchieveProgress3, // Scout Milestone 3
	Achievement_ScoutBackscatterKillSpyGrind, // Back in Business
	Achievement_ScoutBackscatterKillHeavyMedicPair, // Back 2 Back (1040)
	Achievement_ScoutBackscatterKillFriendsGrind, // Severed Ties (1041)
	
	
	// 1100: Sniper Achievements
	Achievement_SniperJarateDominated = 1101, // Rode Hard, Put Away Wet
	Achievement_SniperFreezecamHat, // Be Polite
	Achievement_SniperRifleNoMissing, // Be Efficient
	Achievement_SniperCaptureFlag, // Have a Plan
	Achievement_SniperKillGrind, // Kill Everyone You Meet
	Achievement_SniperKillWeapons, // Triple Prey
	Achievement_SniperHeadshotSnipers, // Self-destruct Sequence
	Achievement_SniperDestroySentryGuns, // De-sentry-lized
	Achievement_SniperKillInvisSpy, // Shoot the Breeze
	Achievement_SniperKillMidairScout, // Dropped Dead (1110)
	Achievement_SniperFreezecamWave, // The Last Wave
	Achievement_SniperDominateSniper, // Australian Rules
	Achievement_SniperKillSpiesMelee, // Kook the Spook
	Achievement_SniperHeadshotDemoman, // Socket to Him
	Achievement_SniperKillRJer, // Jumper Stumper
	Achievement_SniperKillObjectives, // Not a Crazed Gunman, Dad
	Achievement_SniperKillUnscoped, // Trust Your Feelings
	Achievement_SniperKillChargedMedic, // Uberectomy
	Achievement_SniperGetBackstabbed, // Consolation Prize
	Achievement_SniperKillAtRoundStart, // Enemy at the Gate (1120)
	Achievement_SniperHeadshotPostInvuln, // Parting Shot
	Achievement_SniperTopScoreboardGrind, // My Brilliant Career
	Achievement_SniperKillFailedSpy, // Shock Treatment
	Achievement_SniperJarateGroup, // Saturation Bombing
	Achievement_SniperJarateMedicPair, // Rain on Their Parade
	Achievement_SniperJarateRevealSpy, // Jarring Transition
	Achievement_SniperJarateExtinguish, // Friendship is Golden
	Achievement_SniperBowPinHeavy, // William Tell Overkill
	Achievement_SniperBowKillMedicPair, // Beaux and Arrows
	Achievement_SniperBowKillFlagcarrier, // Robbin' Hood (1130)
	Achievement_SniperBowPincushion, // Pincushion
	Achievement_SniperJarateAssists, // Number One Assistant
	Achievement_SniperJarateKillMelee, // Jarate Chop
	Achievement_SniperTauntKill, // Shafted
	Achievement_SniperBowKillWhileDead, // Dead Reckoning
	Achievement_SniperAchieveProgress1, // Sniper Milestone 1
	Achievement_SniperAchieveProgress2, // Sniper Milestone 2
	Achievement_SniperAchieveProgress3, // Sniper Milestone 3
	Achievement_SniperClassicRifleNoscopeHeadshot, // Hipshot
	Achievement_SniperClassicRifleHeadshotJumper, // Eagle Eye (1140)
	Achievement_SniperClassicRifleGibGrind, // Prime Cuts
	Achievement_SniperParachuteGrind, // Flight Cancelled (1142)
	
	
	// 1200: Soldier Achievements
	Achievement_SoldierRJEqualizerKill = 1201, // Duty Bound
	Achievement_SoldierBuffTeammates, // The Boostie Boys
	Achievement_SoldierKillDemomanGrind, // Out, Damned Scot!
	Achievement_SoldierKillEngy, // Engineer to Eternity
	Achievement_SoldierKillPyro, // Backdraft Dodger
	Achievement_SoldierNemesisShovelKill, // Trench Warfare
	Achievement_SoldierDestroyStickies, // Bomb Squaddie
	Achievement_SoldierCrouchRocketJump, // Where Eagles Dare
	Achievement_SoldierEqualizerStreak, // Ain't Got Time to Bleed
	Achievement_SoldierBuffFriends, // Banner of Brothers (1210)
	Achievement_SoldierKillGroupWithCrocket, // Tri-Splatteral Damage
	Achievement_SoldierKillTwoDuringRocketJump, // Death from Above
	Achievement_SoldierKillTaunt, // Spray of Defeat
	Achievement_SoldierDefendMedic, // War Crime and Punishment
	Achievement_SoldierKillWithEqualizerWhileHurt, // Near Death Experience
	Achievement_SoldierKillAirborneTargetWhileAirborne, // Wings of Glory
	Achievement_SoldierBounceThenShotgun, // For Whom the Shell Trolls
	Achievement_SoldierKillAirborneWithDirectHit, // Death From Below
	Achievement_SoldierKillSniperWhileDead, // Mutually Assured Destruction
	Achievement_SoldierDestroySentryOutOfRange, // Guns of the Navar0wned (1220)
	Achievement_SoldierDuoSoldierKills, // Brothers in Harms
	Achievement_SoldierMVP, // Medals of Honor
	Achievement_SoldierAssistMedicUber, // S*M*A*S*H
	Achievement_SoldierShootMultCrits, // Crockets Are Such B.S.
	Achievement_SoldierKillDefenseless, // Geneva Contravention
	Achievement_SoldierKillOnFire, // Semper Fry
	Achievement_SoldierFreezecamTaunt, // Worth a Thousand Words
	Achievement_SoldierFreezecamGibs, // Gore-a! Gore-a! Gore-a!
	Achievement_SoldierKillSpyKiller, // War Crime Spybunal
	Achievement_SoldierGibGrind, // Frags of our Fathers (1230)
	Achievement_SoldierThreeDominations, // Dominator
	Achievement_SoldierRideTheCart, // Ride of the Valkartie
	Achievement_SoldierKillTwentyFromAbove, // Screamin' Eagle
	Achievement_SoldierKillFiveStunned, // The Longest Daze
	Achievement_SoldierDefendCapThirtyTimes, // Hamburger Hill
	Achievement_SoldierAchieveProgress1, // Soldier Milestone 1
	Achievement_SoldierAchieveProgress2, // Soldier Milestone 2
	Achievement_SoldierAchieveProgress3, // Soldier Milestone 3
	Achievement_SoldierParachuteKillGroup, // Upper Hand
	Achievement_SoldierParachuteDistance, // Project Excelsior (1240)
	Achievement_SoldierParachuteKillParachute, // Dogfight
	Achievement_SoldierAirstrikeMaxClip, // Maximum Potential
	Achievement_SoldierAirstrikeGroupKill, // Bombs Away! (1243)
	
	
	// 1300: Demoman Achievements
	Achievement_DemomanKillSoldierGrind = 1301, // Kilt in Action
	Achievement_DemomanDestroyBuildingsWithMedic, // Tam O'Shatter
	Achievement_DemomanDecapitateCloakedSpy, // Shorn Connery
	Achievement_DemomanKillXWithDirectPipe, // Laddy Macdeth
	Achievement_DemomanBounceAndKill, // Caber Toss
	Achievement_DemomanKillTwoDuringStickyJump, // Double Mauled Scotch
	Achievement_DemomanKillPlayerAfterTP, // Loch Ness Bombster
	Achievement_DemomanDominateThreeEngineers, // Three Times a Laddy
	Achievement_DemomanKillBuildingDirectHit, // Blind Fire
	Achievement_DemomanDecapitatePlayers, // Brainspotting (1310)
	Achievement_DemomanDecapitatePlayersFast, // Left 4 Heads
	Achievement_DemomanDuoDemomanKills, // Well Plaid!
	Achievement_DemomanMeleeKillWhileStickyjumping, // The Scottish Play
	Achievement_DemomanKillEngiSentryDispenser, // The Argyle Sap
	Achievement_DemomanDecapitateEqualizer, // Slammy Slayvis Woundya
	Achievement_DemomanDecapitateNemesis, // There Can Be Only One
	Achievement_DemomanDamageGrind, // Tartan Spartan
	Achievement_DemomanKillXCappingOneDet, // Scotch Guard
	Achievement_DemomanKillXDefending, // Bravehurt
	Achievement_DemomanDestroyBuildingsGrind, // Cry Some Moor! (1320)
	Achievement_DemomanKillXHeaviesFullHPOneDet, // The Stickening
	Achievement_DemomanKillXScoutsPyros, // Glasg0wned
	Achievement_DemomanTauntKill, // Scotch Tap
	Achievement_DemomanChargeKill, // The Targe Charge
	Achievement_DemomanCritSwordKill, // Beat Me Up, Scotty
	Achievement_DemomanAirBurstKills, // Something Stickied This Way Comes
	Achievement_DemomanStickyJumpCap, // The High Road
	Achievement_DemomanFreezecamSmile, // Bloody Merry
	Achievement_DemomanFreezecamRump, // Second Eye
	Achievement_DemomanEnvironmentalKill, // He Who Celt It (1330)
	Achievement_DemomanDestroyXStickybombs, // Robbed Royal
	Achievement_DemomanStickJumpDistance, // Highland Fling
	Achievement_DemomanKill3WithDetonation, // Pipebagger
	Achievement_DemomanKillXSappingSpies, // Spynal Tap
	Achievement_DemomanKill3WithPipeSetups, // Sticky Thump
	Achievement_DemomanAchieveProgress1, // Demoman Milestone 1
	Achievement_DemomanAchieveProgress2, // Demoman Milestone 2
	Achievement_DemomanAchieveProgress3, // Demoman Milestone 3
	Achievement_DemomanParachuteKillGroup, // Air Raid
	Achievement_DemomanParachuteDistance, // Operation High Dive (1340)
	Achievement_DemomanParachuteKillParachute, // Flight Control
	Achievement_DemomanKillPlayerYouDidntSee, // U-Turn
	Achievement_DemomanQuickKills, // Chain Reaction
	Achievement_DemomanChargeKillChargingDemo, // Head-On Collision (1344)
	
	
	// 1400: Medic Achievements
	Achievement_MedicTopScoreboard = 1401, // First Do No Harm
	Achievement_MedicHealUnderFire, // Quadruple Bypass
	Achievement_MedicSimulCharge, // Group Health
	Achievement_MedicSetupCharge, // Surgical Prep
	Achievement_MedicRapidCharge, // Trauma Queen
	Achievement_MedicCounterCharge, // Double Blind Trial
	Achievement_MedicSwitchToMedic, // Play Doctor
	Achievement_MedicSaveTeammate, // Triage
	Achievement_MedicChargeBlocker, // Preventive Medicine
	Achievement_MedicAssistMedic, // Consultation (1410)
	Achievement_MedicSyringeScouts, // Does It Hurt When I Do This?
	Achievement_MedicBonesawMedics, // Peer Review
	Achievement_MedicAssistHeavyLong, // Big Pharma
	Achievement_MedicAssistScout, // You'll Feel a Little Prick
	Achievement_MedicAssistPyro, // Autoclave
	Achievement_MedicAssistHeavy, // Blunt Trauma
	Achievement_MedicAssistDemoman, // Medical Breakthrough
	Achievement_MedicAssistSoldier, // Blast Assist
	Achievement_MedicHealEngineer, // Midwife Crisis
	Achievement_MedicAssistCapturer, // Ubi concordia, ibi victoria (1420)
	Achievement_MedicHealCallers, // Grand Rounds
	Achievement_MedicExtinguishTeammates, // Infernal Medicine
	Achievement_MedicAssistVsNemeses, // Doctor Assisted Homicide
	Achievement_MedicKillWhileCharged, // Placebo Effect
	Achievement_MedicBonesawNoMisses, // Sawbones
	Achievement_MedicHealLarge, // Intern
	Achievement_MedicHealHuge, // Specialist
	Achievement_MedicHealGrind, // Chief of Staff
	Achievement_MedicKillHealedSpy, // Hypocritical Oath
	Achievement_MedicSaveFallingTeammate, // Medical Intervention (1430)
	Achievement_MedicChargeJuggle, // Second Opinion
	Achievement_MedicFreezecamRagdoll, // Autopsy Report
	Achievement_MedicBonesawSpyCallers, // FYI I am A Medic
	Achievement_MedicChargeFriends, // Family Practice
	Achievement_MedicInviteJoinCharge, // House Call
	Achievement_MedicHealAchiever, // Bedside Manner
	Achievement_MedicAchieveProgress1, // Medic Milestone 1
	Achievement_MedicAchieveProgress2, // Medic Milestone 2
	Achievement_MedicAchieveProgress3, // Medic Milestone 3 (1439)
	
	
	// 1500: Heavy Achievements
	Achievement_HeavyDamageTaken = 1501, // Iron Kurtain
	Achievement_HeavyDefendMedic, // Party Loyalty
	Achievement_HeavyAssistMedicLarge, // Division of Labor
	Achievement_HeavyEarnMedicDomination, // Red Oktoberfest
	Achievement_HeavyKillTaunt, // Show Trial
	Achievement_HeavyKillFlagCarriers, // Crime and Punishment
	Achievement_HeavyKillMedicPair, // Class Struggle
	Achievement_HeavyBlockInvulnHeavy, // Soviet Block
	Achievement_HeavyBlockCart, // Stalin the Kart
	Achievement_HeavyReceiveUberGrind, // Supreme Soviet (1510)
	Achievement_HeavyStandNearDispenser, // Factory Worker
	Achievement_HeavyAssistHeavyGrind, // Soviet Union
	Achievement_HeavyClearStickybombs, // 0wn the Means of Production
	Achievement_HeavyKillUnderwater, // Krazy Ivan
	Achievement_HeavyTakeMultiDamage, // Rasputin
	Achievement_HeavyKillDominated, // Icing on the Cake
	Achievement_HeavySurviveCrocket, // Crock Block
	Achievement_HeavyAssistGrind, // Kollectivization
	Achievement_HeavyUncoverSpies, // Spyalectical Materialism
	Achievement_HeavyKillWhileSpunup, // Permanent Revolution (1520)
	Achievement_HeavyFireLots, // Heavy Industry
	Achievement_HeavyKillCritPunch, // Communist Mani-Fisto
	Achievement_HeavyHealMediKits, // Redistribution of Health
	Achievement_HeavyKillShotgun, // Rationing
	Achievement_HeavyFirstToCap, // Vanguard Party
	Achievement_HeavyPayloadCapGrind, // Pushkin the Kart
	Achievement_HeavyKillMidairMinigun, // Marxman
	Achievement_HeavyDefendControlPoint, // Gorky Parked
	Achievement_HeavyKillCappingEnemies, // Purge
	Achievement_HeavyRevengeAssist, // Lenin A Hand (1530)
	Achievement_HeavyTeleportFastKill, // Five Second Plan
	Achievement_HeavyFreezecamTaunt, // Photostroika
	Achievement_HeavyEatSandwiches, // Konspicuous Konsumption
	Achievement_HeavyKillScouts, // Don't Touch Sandvich
	Achievement_HeavyKillHeaviesGloves, // Borscht Belt
	
	Achievement_HeavyAchieveProgress1 = 1537, // Heavy Milestone 1
	Achievement_HeavyAchieveProgress2, // Heavy Milestone 2
	Achievement_HeavyAchieveProgress3, // Heavy Milestone 3
	
	
	// 1600: Pyro Achievements
	Achievement_PyroKillMultiWeapons = 1601, // Combined Fire
	Achievement_PyroSimulburnScouts, // Weenie Roast
	Achievement_PyroForceWaterJump, // Baptism by Fire
	Achievement_PyroKillPostdeath, // Fire and Forget
	Achievement_PyroKillSpies, // Firewall
	Achievement_PyroKillCarriers, // Cooking the Books
	Achievement_PyroRevealSpies, // Spontaneous Combustion
	Achievement_PyroCampTeleporters, // Trailblazer
	Achievement_PyroCampPosition, // Camp Fire
	Achievement_PyroKillAxeSmall, // Lumberjack (1610)
	Achievement_PyroKillAxeLarge, // Clearcutter
	Achievement_PyroKillFromBehind, // Hot on Your Heels
	Achievement_PyroBurnSpiesAsYou, // I Fry
	Achievement_PyroBurnSnipersZoomed, // Firewatch
	Achievement_PyroBurnMedicsCharged, // Burn Ward
	Achievement_PyroReflectProjectiles, // Hot Potato
	Achievement_PyroKillHeavies, // Makin' Bacon
	Achievement_PyroKillUnderwater, // Plan B
	Achievement_PyroKillUbercharge, // Pyrotechnics
	Achievement_PyroDestroyBuildings, // Arsonist (1620)
	Achievement_PyroDefendPoints, // Controlled Burn
	Achievement_PyroKillGrind, // Firefighter
	Achievement_PyroDamageGrind, // Pyromancer
	Achievement_PyroBurnMedicpair, // Next of Kindling
	Achievement_PyroKillTaunt, // OMGWTFBBQ
	Achievement_PyroKillTeamwork, // Second Degree Burn
	Achievement_PyroBurnSpyTaunt, // Got A Light?
	Achievement_PyroDominateLeaveSvr, // BarbeQueQ
	Achievement_PyroReflectCrocketKill, // Hotshot
	Achievement_PyroKillTaunters, // Dance Dance Immolation (1630)
	Achievement_PyroDoubleKO, // Dead Heat
	Achievement_PyroBurnRJSoldier, // Pilot Light
	Achievement_PyroFreezecamTaunts, // Freezer Burn
	Achievement_PyroKillGrindLarge, // Fire Chief
	Achievement_PyroIgniteFlaregun, // Attention Getter
	Achievement_PyroAchieveProgress1, // Pyro Milestone 1
	Achievement_PyroAchieveProgress2, // Pyro Milestone 2
	Achievement_PyroAchieveProgress3, // Pyro Milestone 3
	Achievement_PyroIgniteWithRainbow, // Full Spectrum Warrior (1640)
	Achievement_PyroIgnitePlayerBeingFlipped, // Flip-Kabob
	
	
	// 1700: Spy Achievements
	Achievement_SpyBackstabSnipers = 1701, // Triplecrossed
	Achievement_SpyFreezecamFlick, // For Your Eyes Only
	Achievement_SpyBackstabDisguisedSpy, // Counter Espionage
	Achievement_SpyBackstabDisguiseTarget, // Identity Theft
	Achievement_SpyTauntKill, // The Man from P.U.N.C.T.U.R.E.
	Achievement_SpyBackstabMedicHealingYou, // FYI I am a Spy
	Achievement_SpyBackstabEngySapBuilding, // The Man with the Broken Guns
	Achievement_SpySapBuildingBackstabEngy, // Sapsucker
	Achievement_SpyBackstabMedicPair, // May I Cut In?
	Achievement_SpyBackstabFriends, // Agent Provocateur (1710)
	Achievement_SpyDominateSniper, // The Melbourne Supremacy
	Achievement_SpyBumpCloakedSpy, // Spies Like Us
	Achievement_SpyKillSpyWithKnife, // A Cut Above
	Achievement_SpySurviveBurning, // Burn Notice
	Achievement_SpyBreakShieldKillSniper, // Die Another Way
	Achievement_SpyKillWorkingEngy, // Constructus Interruptus
	Achievement_SpyFastCap, // On Her Majesty's Secret Surface
	Achievement_SpyMedicHealingKillEnemy, // Insurance Fraud
	Achievement_SpyKillCPDefenders, // Point Breaker
	Achievement_SpyBackstabDominatingEnemy, // High Value Target (1720)
	Achievement_SpyRevengeWithBackstab, // Come in From the Cold
	Achievement_SpyKnifeKillWhileJarated, // Wetwork
	Achievement_SpyBackstabQuickKills, // You Only Shiv Thrice
	Achievement_SpyBackstabGrind, // Spymaster
	Achievement_SpySapperGrind, // Sap Auteur
	Achievement_SpySapperTeamwork, // Joint Operation
	Achievement_SpyBackstabMedicCharged, // Dr. Nooooo
	Achievement_SpyBackstabCappingEnemies, // Is It Safe?
	Achievement_SpyBackstabEnemySwitchPyro, // Slash and Burn
	Achievement_SpyAmbassadorGrind, // Diplomacy (1730)
	Achievement_SpyAmbassadorSniperGrind, // Skullpluggery
	Achievement_SpyFeignDeathKill, // Sleeper Agent
	Achievement_SpyAmbassadorScoutGrind, // Who's Your Daddy?
	Achievement_SpyCampPosition, // Deep Undercover
	Achievement_SpyAchieveProgress1, // Spy Milestone 1
	Achievement_SpyAchieveProgress2, // Spy Milestone 2
	Achievement_SpyAchieveProgress3, // Spy Milestone 3
	Achievement_SpyKillBackscatterScout, // Fast Fingers (1738)
	
	
	// 1800: Engineer Achievements
	Achievement_EngineerAchieveProgress1 = 1801, // Engineer Milestone 1
	Achievement_EngineerAchieveProgress2, // Engineer Milestone 2
	Achievement_EngineerAchieveProgress3, // Engineer Milestone 3
	Achievement_EngineerRevengeCritSentryKiller, // Revengineering
	Achievement_EngineerTeleportGrind, // Battle Rustler
	Achievement_EngineerDispenserExtinguish, // The Extinguished Gentleman
	Achievement_EngineerManualCloakedSpyKill, // Search Engine
	Achievement_EngineerRevengeCritLife, // Unforgiven
	Achievement_EngineerManualSentryAbsorbDmg, // Building Block
	Achievement_EngineerManualSentryKillsBeyondRange, // Pownd on the Range (1810)
	Achievement_EngineerUpgradeBuildings, // Silent Pardner
	Achievement_EngineerDispenserHealGroup, // Doc Holiday
	Achievement_EngineerSentryKillLifetimeGrind, // Best Little Slaughterhouse in Texas
	Achievement_EngineerWasteMetalGrind, // Death Metal
	Achievement_EngineerKillFlagCarriers, // Trade Secrets
	Achievement_EngineerKillDisguisedSpy, // The Wrench Connection
	Achievement_EngineerHelpBuildStructure, // Land Grab
	Achievement_EngineerFreezecamTaunt, // Six-String Stinger
	Achievement_EngineerFreezecamSentry, // Uncivil Engineer
	Achievement_EngineerShotgunKillPrevSentryTarget, // Texas Two-Step (1820)
	Achievement_EngineerSentryAvengesYou, // Frontier Justice
	Achievement_EngineerRepairSentryWMedic, // Doc, Stock, and Barrel
	Achievement_EngineerSentryKillCaps, // No Man's Land
	Achievement_EngineerDestroySappers, // Fistful of Sappers
	Achievement_EngineerKillSpyTwoSappers, // Quick Draw
	Achievement_EngineerRemoveSapperLongDist, // Get Along!
	Achievement_EngineerTauntKill, // Honky Tonk Man
	Achievement_EngineerDestroyStickies, // How the Pests Was Gunned
	Achievement_EngineerHelpManualSentry, // Rio Grind
	Achievement_EngineerKillSnipersSentry, // Breaking Morant (1830)
	Achievement_EngineerKillSentryWithSentry, // Patent Protection
	Achievement_EngineerMoveSentryGetKill, // If You Build It, They Will Die
	Achievement_EngineerBuildingCarry, // Texas Ranger
	Achievement_EngineerKillAssist, // Deputized
	Achievement_EngineerDispenserHealGrind, // Drugstore Cowboy
	Achievement_EngineerRepairTeamGrind, // Circle the Wagons
	Achievement_EngineerTankDamage, // Built to Last
	Achievement_EngineerHeavyAssist, // (Not So) Lonely Are the Brave (1838)
	
	
	// 1900: Halloween Event Achievements
	Achievement_HalloweenCollectPumpkins = 1901, // Candy Coroner
	Achievement_HalloweenDominateForHat, // Ghastly Gibus Grab
	Achievement_HalloweenKillScaredPlayer, // Scared Stiff
	Achievement_HalloweenPumpkinKill, // Attack o' Lantern
	Achievement_HalloweenDisguisedSpyKill, // Costume Contest
	Achievement_HalloweenBossKill, // Sleepy Holl0WND
	Achievement_HalloweenCollectGoodyBag, // Masked Mann
	Achievement_HalloweenCraftSaxtonMask, // Sackston Hale
	Achievement_HalloweenBossKillMelee, // Gored!
	Achievement_HalloweenEyebossKill, // Optical Defusion (1910)
	Achievement_HalloweenLootIsland, // Dive Into a Good Book
	Achievement_HalloweenMerasmusCollectLoot, // A Lovely Vacation Spot
	Achievement_HalloweenMerasmusKill, // Wizards Never Prosper
	Achievement_HalloweenHelltowerRareSpell, // Helltower: Hell's Spells
	Achievement_HalloweenHelltowerWinRounds, // Helltower: Competitive Spirit
	Achievement_HalloweenHelltowerEnvironmentalKills, // Helltower: Mine Games
	Achievement_HalloweenHelltowerSkeletonGrind, // Helltower: Skeleton Coup
	Achievement_HalloweenHelltowerKillGrind, // Helltower: Spelling Spree
	Achievement_HalloweenHelltowerKillBrothers, // Helltower: Hell on Wheels
	Achievement_HalloweenHelltowerMilestone, // Helltower: The Mann-tastic Four (1920)
	Achievement_HalloweenHelltowerSkullIslandReward, // Helltower: Hat Out of Hell
	Achievement_HalloweenDoomsdayKillKarts, // Carnival of Carnage: Bumper Crop
	Achievement_HalloweenDoomsdayCollectDucks, // Carnival of Carnage: Up All Night To Get Ducky
	Achievement_HalloweenDoomsdayScoreGoals, // Carnival of Carnage: Hat Trick
	Achievement_HalloweenDoomsdayRespawnTeammates, // Carnival of Carnage: ReinKartnation
	Achievement_HalloweenDoomsdayTinySmasher, // Carnival of Carnage: Arms Reduction
	Achievement_HalloweenDoomsdayWinMinigames, // Carnival of Carnage: Bumper to Bumper to Bumper
	Achievement_HalloweenDoomsdayMilestone, // Carnival of Carnage: Step Right Up (1928)
	
	
	// 2000: Replay Achievements
	Achievement_ReplaySaveReplay = 2001, // That's a Wrap
	Achievement_ReplayPerformanceMode, // We Can Fix It In Post
	Achievement_ReplayBrowseReplays, // Time For Your Close-Up, Mr. Hale
	Achievement_ReplayEditTime, // Star of My Own Show
	Achievement_ReplayYoutubeViewsTier1, // Home Movie
	Achievement_ReplayYoutubeViewsTier2, // Local Cinema Star
	Achievement_ReplayYoutubeViewsTier3, // Indie Film Sensation
	Achievement_ReplayYoutubeViewsHighest, // Blockbuster (2008)
	
	
	// 2100: Christmas 2011 Achievement
	Achievement_ChristmasCollectGifts = 2101, // Gift Grab
	
	
	// 2200: Foundry Achievements
	Achievement_MapsFoundryKillCappingEnemy = 2201, // Cap Trap
	Achievement_MapsFoundryPlayGameFriends, // Foundry Force Five
	Achievement_MapsFoundryWinMinTime, // Two Minute Warring
	Achievement_MapsFoundryWinRounds, // The Crucible
	Achievement_MapsFoundryFastFinalCap, // Five the Fast Way
	Achievement_MapsFoundryTeleportAndCap, // Claim Jumper
	Achievement_MapsFoundryPushIntoCauldron, // Terminated, Too
	Achievement_MapsFoundryPushBackAndWin, // Real Steal
	Achievement_MapsFoundryPlayEachClass, // Classassin
	Achievement_MapsFoundryKillEnemyOnRoof, // Raze the Roof (2210)
	Achievement_MapsFoundryBackAndForthBattle, // Dead Heat
	Achievement_MapsFoundryAchieveProgress1, // Foundry Milestone (2212)
	
	
	// 2300: Mann vs. Machine Achievements
	Achievement_MvMCompletePopFile = 2301, // Steel Fragnolias
	Achievement_MvMEarnMoneyBonus, // Wage Against the Machine
	Achievement_MvMAdvancedEarnAllBonuses, // Frags to Riches
	Achievement_MvMPickupMoneyAboutToExpire, // Fast Cache
	Achievement_MvMCollectMoneyGrind, // T-1000000
	Achievement_MvMPlayGameFriends, // Brotherhood of Steel
	Achievement_MvMPlayEachClass, // Hack of All Trades
	Achievement_MvMDestroyTwoTanks, // Clockwork Carnage
	Achievement_MvMDestroyTankWhileDeploying, // Balls-E
	Achievement_MvMDestroyTankQuickly, // Clockwork Conqueror (2310)
	Achievement_MvMDefendCap, // Spam Blocker
	Achievement_MvMKillBombCarriers, // .executioner
	Achievement_MvMCompleteWaveWithoutDying, // Deus Ex Machina
	Achievement_MvMCompleteTour, // Raid Array
	Achievement_MvMUseTeleportBottle, // Ghost in the Machine
	Achievement_MvMUseCritBottle, // Kritical Terror
	Achievement_MvMUseUberBottle, // German Engineering
	Achievement_MvMUseBuildBottle, // Undelete
	Achievement_MvMUseAmmoBottle, // Shell Extension
	Achievement_MvMMaxPrimaryUpgrades, // System Upgrade (2320)
	Achievement_MvMMaxPlayerResistances, // Maximum Performance
	Achievement_MvMNoAlarmsInFinalWave, // Engine Block
	Achievement_MvMKillMedicsCharged, // Negative Charge
	Achievement_MvMKillRobotGrind, // Silicon Slaughter
	Achievement_MvMKillRobotMegaGrind, // Metal Massacre
	Achievement_MvMKillSentryBuster, // Ctrl + Assault + Delete
	Achievement_MvMSpySapRobots, // Sly Voltage
	Achievement_MvMSoldierBuffTeam, // Turbocharger
	Achievement_MvMHeavyRagePushDeployingRobot, // Heavy Mettle
	Achievement_MvMMedicShareBottles, // Vial Sharing (2330)
	Achievement_MvMDemoGroupKill, // Tech Wrecker
	Achievement_MvMScoutMarkForDeath, // Do Androids Dream?
	Achievement_MvMSniperKillGroup, // Spark Plugger
	Achievement_MvMPyroBombReset, // Hard Reset
	Achievement_MvMEngineerEscapeSentryBuster, // Real Steal (2335)
	
	Achievement_MvMMapsRottenburgTank = 2339, // Palace-Aid (2339)
	Achievement_MvMMapsRottenburgBomb, // Crasher Crusher (2340)
	Achievement_MvMMapsRottenburgPitGrind, // A Bygone Century
	Achievement_MvMMapsMannhattanPit, // Chippin' In
	Achievement_MvMMapsMannhattanMystery, // Now Legal To Eat
	Achievement_MvMMapsMannhattanNoGates, // Get Off My Lawn
	Achievement_MvMMapsMannhattanStunRadiowave, // Software Downgrade
	Achievement_MvMMapsMannhattanBombBotGrind, // Urban Strike
	Achievement_MvMSentryBusterFriendlyFire, // Bot-Buster
	Achievement_MvMSniperCollectHeadshotMoney, // Bank On It
	Achievement_MvMMedicShieldBlockDamage, // Wall Of Pain
	Achievement_MvMMedicReviveTeammates, // Reanimator 2 (2350)
	Achievement_MvMRocketSpecialistKillGrind, // Robot Flush
	Achievement_MvMRocketSpecialistStunGrind, // Dazed And Defused
	
	
	// 2400: Astro-chievements
	Achievement_MapsDoomsdaySoloCapture = 2401, // Mission Control
	Achievement_MapsDoomsdayPlayGameFriends, // Flight Crew
	Achievement_MapsDoomsdayWinRounds, // The Fight Stuff
	Achievement_MapsDoomsdayPlayEachClass, // Plan Nine to Outer Space
	Achievement_MapsDoomsdayKillEnemiesOnElevator, // Failure to Launch
	Achievement_MapsDoomsdayPushBackAndWin, // Rocket Booster
	Achievement_MapsDoomsdayKillCarriers, // Best Case Scenario
	Achievement_MapsDoomsdayRideTheElevator, // Cap-ogee
	Achievement_MapsDoomsdayDenyNeutralPickup, // Space Camp
	Achievement_MapsDoomsdayPushIntoExhaust, // Lift-offed (2410)
	Achievement_MapsDoomsdayDefendCarrier, // Escape Ferocity
	Achievement_MapsDoomsdayAchieveProgress1, // Doomsday Milestone (2412)
	
	
	// 2500: Process Achievements
	Achievement_MapsProcessWinRounds = 2501, // Process Of Elimination
	
	
	// 2600: Standin Achievements
	Achievement_MapsStandinWinRounds = 2601, // Stand And Deliver
	
	
	// 2700: Snakewater Achievements
	Achievement_MapsSnakewaterWinRounds = 2701, // Snakewater Salesman
	Achievement_MapsSnakewaterPushBackAndWin, // Snakebit
	Achievement_MapsSnakewaterTeamKill, // The Snakeout
	Achievement_MapsSnakewaterDoubleAirDeaths, // Mutually Air-Sured-Destruction
	Achievement_MapsSnakewaterKillEnemiesInMiddle, // Log Jammin (2705)
	
	
	// 2800: Powerhouse Achievements
	Achievement_MapsPowerhouseWinRounds = 2801, // The Power and the Glory
	Achievement_MapsPowerhousePushBackAndWin, // Balance of Power
	Achievement_MapsPowerhouseFastFinalCap, // Power Trip
	Achievement_MapsPowerhouseKillCappingPlayer, // Power Down
	Achievement_MapsPowerhouseKillEnemyInWater, // Wet Work (2805)
}
