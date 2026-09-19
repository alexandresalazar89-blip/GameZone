tellTarget("/")
{
   g = 1;
   while(g < 5)
   {
      Ghost[g]._visible = true;
      g++;
   }
   Pacman._visible = true;
   Ready.gotoAndStop(1);
}
