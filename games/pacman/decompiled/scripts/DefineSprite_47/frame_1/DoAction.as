stop();
col = new Array(14483456,16751001,6750207,16750848);
i = 0;
while(i < 4)
{
   G.attachMovie("Ghost",i,i);
   tellTarget(G[i])
   {
      _X = -200;
      Eyes.gotoAndStop(2);
   }
   this["c" + i] = new Color(G[i].Shape);
   this["c" + i].setRGB(col[i]);
   i++;
}
ck = new Color("GK");
GK.kval = 100;
count = 0;
