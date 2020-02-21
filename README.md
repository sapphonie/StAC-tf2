```
////////////////////////////////////////////////////////////////////////////////////
//                                                                                //
//  THIS IS NOT A COMPLICATED ANTICHEAT PLUGIN.                                   //
//  PEOPLE SMARTER THAN ME HAVE WRITTEN THOSE.                                    //
//                                                                                //
//  SEE HERE: -> https://github.com/Silenci0/SMAC                                 //
//  OR HERE:  -> https://forums.alliedmods.net/showthread.php?t=321480            //
//                                                                                //
//  If someone is using an actual cheat, like nullcore or lithium or lmaobox,     //
//  this plugin will likely do nothing at all. This is merely to prevent          //
//  otherwise vanilla players from cheating with easily exploitable methods.      //
//                                                                                //
//                                                                                //
//  Currently prevents:                                                           //
//   -> interp abuse               (checks cl_interp above .1, instakick)         //
//   -> (hopefully) box shadows    (checks a series of convars, instakick)        //
//   -> clients using turn binds   (WARNS CLIENT, then kicks after 3 violations)  //
//   -> client ping >= 200         (WARNS CLIENT, then kicks after 3 violations)  //
//   -> client packet loss >= 30%  (WARNS CLIENT, then kicks after 3 violations)  //
//                                                                                //
//  Currently notifies to console of:                                             //
//   -> cmdrate pingmasking (if cmdrate is > 60 or has nonnumerical chars)        //
//                                                                                //
//  Todo (may not be possible):                                                   //
//   -> fix spy decloak exploit / other soundscript exploits                      //
//   -> fix other sv pure stuff (flat / invisible textures)                       //
//   -> fix sniper scope removal exploit                                          //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////
```
