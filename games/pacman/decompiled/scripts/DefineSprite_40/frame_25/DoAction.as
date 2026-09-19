tellTarget("/")
{
   BGSnd.gotoAndPlay("Killed");
   for(var g in Ghost)
   {
      Ghost[g]._visible = false;
   }
}
