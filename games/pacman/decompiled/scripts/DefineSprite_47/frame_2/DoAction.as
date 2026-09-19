count++;
if(count < 86)
{
   Pac._x += 4;
   i = 0;
   while(i < 4)
   {
      if(count > 6 * i + 10)
      {
         G[i]._x += 4;
      }
      i++;
   }
}
else if(count == 86)
{
   Pill._visible = false;
   Pac._rotation = 0;
   i = 0;
   while(i < 4)
   {
      G[i].gotoAndStop(2);
      this["c" + i].setRGB(50344959);
      i++;
   }
}
else if(count < 172)
{
   Pac._x -= 4;
   i = 0;
   while(i < 4)
   {
      with(G[i])
      {
         _x -= 2;
         if(_visible && Shape.Hit.hitTest(Pac.Hit))
         {
            _visible = false;
            GK._x = _x;
            GK.kval *= 2;
         }
      }
      i++;
   }
   if(count == 155)
   {
      GK.kval = "";
   }
}
else if(count == 172)
{
   i = 0;
   while(i < 4)
   {
      this["c" + i].setRGB(col[i]);
      tellTarget(G[i])
      {
         gotoAndStop(1);
         Eyes.gotoAndStop(2);
         _visible = true;
         _X = -200;
      }
      i++;
   }
   tellTarget("GK")
   {
      _X = -16;
      _xscale = _xscale * 2;
      _yscale = _yscale * 2;
   }
}
else if(count < 580)
{
   i = 0;
   while(i < 4)
   {
      if(count == 244 + 90 * i)
      {
         ck.setRGB(col[i]);
         if(i == 0)
         {
            GK.kval = "\"BLINKY\"";
         }
         if(i == 1)
         {
            GK.kval = "\"PINKY\"";
         }
         if(i == 2)
         {
            GK.kval = "\"INKEY\"";
         }
         if(i == 3)
         {
            GK.kval = "\"CLYDE\"";
         }
      }
      else if(count > 180 + 90 * i && count < 244 + 90 * i || count > 270 + 90 * i && count < 307 + 90 * i)
      {
         G[i]._x += 4;
         GK.kval = "";
      }
      i++;
   }
}
else
{
   tellTarget("GK")
   {
      _X = -200;
      _xscale = 100;
      _yscale = 100;
      kval = 100;
   }
   i = 0;
   while(i < 4)
   {
      G[i]._x = -200;
      i++;
   }
   tellTarget("Pac")
   {
      _X = -196;
      _rotation = 180;
   }
   ck.setRGB(16777215);
   Pill._visible = true;
   count = 0;
}
