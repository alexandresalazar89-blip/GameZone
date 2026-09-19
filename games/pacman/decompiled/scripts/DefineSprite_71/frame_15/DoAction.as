stop();
tellTarget("/")
{
   if(notMute)
   {
      Snd.gotoAndPlay("EatFruit");
   }
}
_root.score += fval;
F.kval = fval;
F.gotoAndPlay(2);
