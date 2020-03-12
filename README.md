```
////////////////////////////////////////////////////////////////////////////////////
//                                                                                //
//                               STEPHAC (StAC)                                   //
//                                                                                //
//    SEE HERE FOR PROBABLY BETTER AC PLUGINS:                                    //
//    LilAC:  -> https://forums.alliedmods.net/showthread.php?t=321480            //
//    SMAC:   -> https://github.com/Silenci0/SMAC                                 //
//                                                                                //
//    This plugin currently prevents:                                             //
//     -> interp abuse                                           -kick            //
//     -> clients using turn binds                               -kick            //
//     -> cmdrate pingmasking if cvar has nonnumerical chars)    -kick            //
//     -> othermodels abuse (lol)                                -ban             //
//     -> (hopefully) fov abuse > 90                             -ban             //
//     -> (hopefully) third person cheats on clients             -ban             //
//                                                                                //
//    Currently notifies to server console of:                                    //
//     -> cmdrate pingmasking (if cmdrate is > 60)                                //
//                                                                                //
//    This plugin also currently reseeds the hl2 random seed at each map start to //
//    attempt to prevent possible nospread exploits by guessing server seed.      //
//    This is currently untested but there is no harm by doing it.                //
//                                                                                //
//    Todo (may not be possible):                                                 //
//     -> break/ban for esp/wallhack shit                                         //
//              (not thru painting but possibly with checking m_bGlowEnabled)     //
//     -> fix spy decloak exploit / other soundscript exploits                    //
//              (in the works)                                                    //
//     -> fix other sv pure stuff (flat / invisible textures)                     //
//     -> fix sniper scope removal exploit                                        //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////
```
