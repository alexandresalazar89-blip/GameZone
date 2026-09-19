tellTarget("/")
{
   Ready._visible = false;
   playing = true;
   nextPacDir = 3;
   play();
   if(notMute)
   {
      BGSnd["Back" + bgNum].start(0,1000);
   }
}
stop();
