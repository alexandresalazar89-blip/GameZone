function initVars()
{
   pacDir = 3;
   pacPos = 0;
   pacX = 14;
   pacY = 23;
   nextX = pacX - 1;
   nextY = pacY;
   nextPacDir = 3;
   ghKill = 100;
   ghBlue = 0;
   numEyes = 0;
   Pacman.gotoAndStop(1);
   pacStep = 4;
   pacPosMax = 2;
   pauseCount = 0;
   with(Pacman)
   {
      _x = OFFX + 12 * pacX;
      _y = OFFY + 12 * pacY;
      _rotation = 0;
   }
   tellTarget(Ghost[1])
   {
      ghPos = 1;
      ghDir = 3;
      ghX = 13;
      ghY = 11;
      ghNX = ghX - 1;
      _Y = _root.OFFY + 132;
      cOrig = 14483456;
   }
   tellTarget(Ghost[2])
   {
      ghDir = 0;
      ghX = 13;
      cOrig = 16751001;
   }
   tellTarget(Ghost[3])
   {
      ghDir = 2;
      ghX = 11;
      cOrig = 6750207;
   }
   tellTarget(Ghost[4])
   {
      ghDir = 2;
      ghX = 15;
      cOrig = 16750848;
   }
   g = 1;
   while(g < 5)
   {
      tellTarget(Ghost[g])
      {
         if(this.g > 1)
         {
            ghPos = 0;
            ghY = 14;
            ghNX = ghX;
            _Y = _root.OFFY + 174;
         }
         _X = _root.OFFX + 12 * ghX + 6;
         gotoAndStop(1);
         Eyes.gotoAndStop(1);
         gNum = 0;
         ghNY = ghY;
         ghStep = 4;
         ghPosMax = 2;
         ghFast = true;
         Shape._visible = true;
         Shape.Hit._visible = true;
         c = new Color(Shape);
         c.setRGB(cOrig);
      }
      g++;
   }
}
function setPacMove(d)
{
   var _loc1_ = d;
   if(_loc1_ == 0)
   {
      nextX = pacX;
      nextY = pacY - 1;
      Pacman._rotation = 90;
   }
   else if(_loc1_ == 1)
   {
      nextX = pacX + 1;
      nextY = pacY;
      Pacman._rotation = 180;
   }
   else if(_loc1_ == 2)
   {
      nextX = pacX;
      nextY = pacY + 1;
      Pacman._rotation = -90;
   }
   else if(_loc1_ == 3)
   {
      nextX = pacX - 1;
      nextY = pacY;
      Pacman._rotation = 0;
   }
}
function setGhMove(d, g)
{
   with(Ghost[g])
   {
      if(d == 0)
      {
         ghNX = ghX;
         ghNY = ghY - 1;
      }
      else if(d == 1)
      {
         ghNX = ghX + 1;
         ghNY = ghY;
      }
      else if(d == 2)
      {
         ghNX = ghX;
         ghNY = ghY + 1;
      }
      else if(d == 3)
      {
         ghNX = ghX - 1;
         ghNY = ghY;
      }
   }
}
function startBGSnd()
{
   var _loc1_ = _root;
   tellTarget("BGSnd")
   {
      if(_loc1_.ghBlue > 2)
      {
         if(_loc1_.numEyes)
         {
            EyesGh.start(0,100);
            BlueGh.stop();
         }
         else
         {
            EyesGh.stop();
            BlueGh.start(0,100);
         }
      }
      else
      {
         BlueGh.stop();
         EyesGh.stop();
         _loc1_["Back" + _loc1_.bgNum].start(0,1000);
      }
   }
}
OFFX = 18;
OFFY = 18;
score = 0;
lastScore = 0;
lives = 3;
level = 0;
fruitNum = 1;
notMute = true;
newLev = true;
newGame = true;
newLife = false;
quttting = false;
quit = false;
Snd.ChSnd = true;
Pacman.Hit._visible = false;
ghPause = 40;
ghBVal = 162;
ghMove = new Array(4);
ghChoice = new Array(4);
ghBest = new Array(4);
var g = 1;
while(g < 5)
{
   Ghost.attachMovie("Ghost",g,g);
   Ghost.attachMovie("GhKill","K" + g,g + 4);
   Ghost["K" + g].kval = "";
   g++;
}
var i = 1;
while(i < 5)
{
   _root["Life" + i].gotoAndStop(1);
   if(i >= lives)
   {
      _root["Life" + i]._visible = false;
   }
   i++;
}
m = "#############################............##............##.####.#####.##.#####.####.##O####.#####.##.#####.####O##.####.#####.##.#####.####.##..........................##.####.##.########.##.####.##.####.##.########.##.####.##......##....##....##......#######.##### ## #####.############.##### ## #####.############.##          ##.############.## ######## ##.############.## # # # ## ##.######L     .   # # # ##   .     R######.## ### #### ##.############.## ######## ##.############.##          ##.############.## ######## ##.############.## ######## ##.#######............##............##.####.#####.##.#####.####.##.####.#####.##.#####.####.##O..##.......  .......##..O####.##.##.########.##.##.######.##.##.########.##.##.####......##....##....##......##.##########.##.##########.##.##########.##.##########.##..........................#############################";
var i = -1;
while(i < 29)
{
   Maze.attachMovie("Empty",i,i + 1);
   i++;
}
pos = 0;
var j = 0;
while(j < 31)
{
   var i = 0;
   while(i < 28)
   {
      Maze[i][j] = m.charAt(pos++);
      pill = false;
      if(Maze[i][j] == ".")
      {
         pill = true;
         Maze[i].attachMovie("Pill","P" + j,pos);
      }
      if(Maze[i][j] == "O")
      {
         pill = true;
         Maze[i].attachMovie("Power","P" + j,pos);
      }
      if(pill)
      {
         with(Maze[i]["P" + j])
         {
            _x = OFFX + 12 * i;
            _y = OFFY + 12 * j;
         }
      }
      i++;
   }
   j++;
}
