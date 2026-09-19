ang = Math.abs(pacDir - nextPacDir) / 2;
if(ang == 1)
{
   pacDir = nextPacDir;
}
else if(pacPos == 0)
{
   tempDir = pacDir;
   pacDir = nextPacDir;
}
setPacMove(pacDir);
if(pacPos == 0)
{
   P = Maze[pacX]["P" + pacY];
   if(P._visible)
   {
      pacStep = 4;
      pacPosMax = 2;
      if(notMute)
      {
         tellTarget("Snd")
         {
            if(ChSnd)
            {
               gotoAndStop("Chomp1");
               play();
            }
            else
            {
               gotoAndStop("Chomp2");
               play();
            }
            ChSnd = !ChSnd;
         }
      }
      P._visible = false;
      pillEat++;
      if(notMute)
      {
         if(pillEat == 180)
         {
            BGSnd.Back1.stop();
            bgNum = 2;
            BGSnd.Back2.start(0,1000);
         }
         else if(pillEat == 230)
         {
            BGSnd.Back2.stop();
            bgNum = 3;
            BGSnd.Back3.start(0,1000);
         }
      }
      if(pillEat == 244)
      {
         newLev = true;
         gotoAndStop("Restart");
      }
      score += 10;
      if(Maze[pacX][pacY] == "O")
      {
         score += 40;
         if(notMute)
         {
            BGSnd["Back" + bgNum].stop();
            BGSnd.BlueGh.start(0,100);
         }
         ghBlue = ghBval;
         ghKill = 100;
         var g = 1;
         while(g < 5)
         {
            tellTarget(Ghost[g])
            {
               if(Shape._visible)
               {
                  c.setRGB(13311);
                  gotoAndStop(2);
                  ghFast = false;
                  e = new Color(PPEyes);
                  e.setRGB(16777215);
               }
            }
            g++;
         }
      }
   }
   else if(++pauseCount % 2)
   {
      pacStep = 4;
      pacPosMax = 2;
   }
   else
   {
      pacStep = 6;
      pacPosMax = 1;
   }
   if(Maze[pacX + 1][pacY] == "L")
   {
      pacX = 28;
      nextX = 27;
      Pacman._x = OFFX + 336;
   }
   else if(Maze[pacX - 1][pacY] == "R")
   {
      pacX = -1;
      nextX = 0;
      Pacman._x = OFFX - 12;
   }
   if(Maze[nextX][nextY] == "#" && ang != 1)
   {
      pacDir = tempDir;
      setPacMove(pacDir);
   }
}
if(!(pacPos == 0 && Maze[nextX][nextY] == "#"))
{
   with(Pacman)
   {
      if(nextX < pacX)
      {
         _x -= pacStep;
         pacPos--;
      }
      else if(nextX > pacX)
      {
         _x += pacStep;
         pacPos++;
      }
      else if(nextY < pacY)
      {
         _y -= pacStep;
         pacPos--;
      }
      else if(nextY > pacY)
      {
         _y += pacStep;
         pacPos++;
      }
   }
   if(pacPos < 0 || pacPos > pacPosMax)
   {
      if(pacPos > pacPosMax)
      {
         pacPos = 0;
      }
      else if(pacPos < 0)
      {
         pacPos = pacPosMax;
      }
      pacX = nextX;
      pacY = nextY;
   }
   if(stopped)
   {
      stopped = false;
      Pacman.play();
   }
}
else if(!stopped)
{
   stopped = true;
   Pacman.gotoAndStop(1);
}
tellTarget("Fruit")
{
   if(_currentframe == 1)
   {
      if(!random(600))
      {
         gotoAndStop(_root.fruitNum);
      }
   }
   else if(fCount)
   {
      if(hitTest(_root.Pacman.Hit))
      {
         gotoAndStop("Show");
      }
      else
      {
         fCount--;
      }
   }
   else
   {
      gotoAndStop(1);
   }
}
if(ghBlue)
{
   ghBlue--;
}
unBlue = false;
var g = 1;
while(g < 5)
{
   with(Ghost[g])
   {
      if(ghBlue && _currentframe == 2)
      {
         if(ghBlue == 50 || ghBlue == 40 || ghBlue == 30 || ghBlue == 20 || ghBlue == 10)
         {
            c.setRGB(16777215);
            e.setRGB(16711680);
         }
         else if(ghBlue == 45 || ghBlue == 35 || ghBlue == 25 || ghBlue == 15 || ghBlue == 5)
         {
            c.setRGB(13311);
            e.setRGB(16777215);
         }
         else if(ghBlue == 1)
         {
            gotoAndStop(1);
            c.setRGB(cOrig);
            ghFast = true;
         }
      }
      gTest = false;
      if(ghPos == 0)
      {
         if(Maze[ghX + 1][ghY] == "L" && ghDir == 3)
         {
            ghX = 29;
            ghNX = 28;
            _x = OFFX + 348;
         }
         else if(Maze[ghX - 1][ghY] == "R" && ghDir == 1)
         {
            ghX = -2;
            ghNX = -1;
            _x = OFFX - 24;
         }
         else if(ghX > 0 && ghX < 27)
         {
            var i = 0;
            while(i < 4)
            {
               ghMove[i] = 1;
               i++;
            }
            oppDir = ghDir >= 2 ? ghDir - 2 : ghDir + 2;
            ghMove[oppDir] = 0;
            if(Maze[ghX][ghY - 1] == "#")
            {
               ghMove[0] = 0;
            }
            if(Maze[ghX + 1][ghY] == "#")
            {
               ghMove[1] = 0;
            }
            if(Maze[ghX][ghY + 1] == "#")
            {
               ghMove[2] = 0;
            }
            if(Maze[ghX - 1][ghY] == "#")
            {
               ghMove[3] = 0;
            }
            pos = 0;
            var i = 0;
            while(i < 4)
            {
               ghChoice[i] = -1;
               if(ghMove[i])
               {
                  ghChoice[pos++] = i;
               }
               i++;
            }
            bestXDir = -1;
            bestYDir = -1;
            if(Shape._visible && _currentframe == 1)
            {
               testX = pacX;
               testY = pacY;
            }
            else
            {
               testX = 13;
               testY = 11;
            }
            if(testX < ghX)
            {
               bestXDir = 3;
            }
            else if(testX > ghX)
            {
               bestXDir = 1;
            }
            if(testY < ghY)
            {
               bestYDir = 0;
            }
            else if(testY > ghY)
            {
               bestYDir = 2;
            }
            best = 0;
            var i = 0;
            while(i < pos)
            {
               if(ghChoice[i] == bestXDir || ghChoice[i] == bestYDir)
               {
                  ghBest[best++] = ghChoice[i];
               }
               i++;
            }
            if(best == 0 || Shape._visible && !random(3))
            {
               ghDir = ghChoice[random(pos)];
            }
            else
            {
               ghDir = ghBest[random(best)];
            }
            if(ghFast)
            {
               ghStep = 4;
               ghPosMax = 2;
            }
            else
            {
               ghStep = 2;
               ghPosMax = 5;
            }
            gNum++;
            if(ghX == 13)
            {
               if(ghY > 11 && ghY < 15)
               {
                  if(Shape._visible)
                  {
                     gTest = true;
                     ghDir = 0;
                     if(gNum < 4)
                     {
                        _y -= 2;
                     }
                  }
                  else if(ghY == 13)
                  {
                     unBlue = true;
                     numEyes--;
                     Shape._visible = true;
                     Shape.Hit._visible = true;
                  }
               }
               else if(ghY == 11)
               {
                  if(gNum == 1 && g == 1)
                  {
                     _x -= 2;
                  }
                  if(gNum == 4)
                  {
                     ghPos = 2;
                     if(ghFast)
                     {
                        _x += 2;
                     }
                     else
                     {
                        _x -= 2;
                     }
                  }
                  if(!Shape._visible)
                  {
                     gTest = true;
                     ghDir = 2;
                  }
               }
            }
            if(ghY > 11 && ghY < 15)
            {
               if(ghX == 11 && gNum == ghPause + 2)
               {
                  gTest = true;
                  ghDir = 1;
                  gNum = -1;
               }
               if(ghX == 15 && gNum == 2 * ghPause + 2)
               {
                  gTest = true;
                  ghDir = 3;
                  gNum = -1;
               }
            }
         }
      }
      setGhMove(ghDir,g);
      if(!(ghPos == 0 && Maze[ghNX][ghNY] == "#") || gTest)
      {
         if(ghNX < ghX)
         {
            _x -= ghStep;
            ghPos--;
         }
         else if(ghNX > ghX)
         {
            _x += ghStep;
            ghPos++;
         }
         else if(ghNY < ghY)
         {
            _y -= ghStep;
            ghPos--;
         }
         else if(ghNY > ghY)
         {
            _y += ghStep;
            ghPos++;
         }
         Eyes.gotoAndStop(ghDir + 1);
         if(ghPos < 0 || ghPos > ghPosMax)
         {
            if(ghPos > ghPosMax)
            {
               ghPos = 0;
            }
            else if(ghPos < 0)
            {
               ghPos = ghPosMax;
            }
            ghX = ghNX;
            ghY = ghNY;
         }
      }
      if(Shape.Hit._visible && Pacman.Hit.hitTest(Shape.Hit) && !newLev)
      {
         if(_currentframe == 1)
         {
            _root.stop();
            playing = false;
            Pacman.gotoAndPlay("Die");
         }
         else
         {
            BGSnd.BlueGh.stop();
            ghKill *= 2;
            score += ghKill;
            ghFast = true;
            if(ghPos > ghPosMax)
            {
               ghPos = 0;
            }
            else if(ghPos < 0)
            {
               ghPos = ghPosMax;
            }
            if(notMute)
            {
               Snd.gotoAndPlay("EatGhost");
            }
            gotoAndStop(1);
            numEyes++;
            Shape._visible = false;
            Shape.Hit._visible = false;
            c.setRGB(cOrig);
            with(Ghost["K" + g])
            {
               _visible = true;
               _x = Ghost[g]._x;
               _y = Ghost[g]._y;
               kval = ghKill;
               play();
            }
         }
      }
   }
   g++;
}
if(ghBlue && notMute)
{
   with(BGSnd)
   {
      if(ghBlue == 1)
      {
         BlueGh.stop();
         EyesGh.stop();
         eval("Back" + bgNum).start(0,1000);
      }
      else if(unBlue && !numEyes)
      {
         EyesGh.stop();
         BlueGh.start(0,100);
      }
   }
}
if(lastScore != score)
{
   s = Math.floor(score / 10000);
   sTest = (s + 1) / 2;
   if(lives < 5 && sTest == int(sTest) && Math.floor(lastScore / 10000) < s)
   {
      eval("Life" + lives)._visible = true;
      lives++;
      if(notMute)
      {
         BGSnd.ExLife.start(0,6);
      }
   }
}
lastScore = score;
if(!playing)
{
   stop();
}
if(quit)
{
   gotoAndStop(2);
}
