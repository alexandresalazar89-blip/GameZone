stop();
stopAllSounds();
playing = false;
stopped = true;
Fruit.gotoAndStop(1);
if(newLev)
{
   newLev = false;
   bgNum = 1;
   pillEat = 0;
   level++;
   if(ghPause > 4)
   {
      ghPause -= 4;
   }
   if(ghBVal > 2)
   {
      ghBVal -= 10;
   }
   if(fruitNum < 14)
   {
      fruitNum++;
      FrLev.gotoAndStop(fruitNum);
   }
   initVars();
   if(!newGame)
   {
      var g = 1;
      while(g < 5)
      {
         Ghost[g]._visible = false;
         g++;
      }
      Pacman._visible = false;
      BGSnd.gotoAndPlay("NewLev");
   }
}
if(newLife)
{
   newLife = false;
   Ready._visible = true;
   lives--;
   if(lives > 0)
   {
      _root["Life" + lives]._visible = false;
      initVars();
      BGSnd.gotoAndPlay("NewLife");
   }
   else
   {
      Pacman._visible = false;
      Ready.gotoAndStop("GameOver");
   }
}
if(newGame)
{
   BGSnd.gotoAndPlay("NewGame");
}
