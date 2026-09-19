tellTarget("/")
{
   if(!newGame)
   {
      Ready.gotoAndStop("Level");
      Ready._visible = true;
      var j = 0;
      while(j < 31)
      {
         var i = 0;
         while(i < 28)
         {
            Maze[i]["P" + j]._visible = true;
            i++;
         }
         j++;
      }
   }
   newGame = false;
}
