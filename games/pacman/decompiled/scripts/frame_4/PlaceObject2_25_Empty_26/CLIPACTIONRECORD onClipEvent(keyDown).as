onClipEvent(keyDown){
   with(_root)
   {
      if(Key.getCode() == 38)
      {
         nextPacDir = 0;
      }
      else if(Key.getCode() == 39)
      {
         nextPacDir = 1;
      }
      else if(Key.getCode() == 40)
      {
         nextPacDir = 2;
      }
      else if(Key.getCode() == 37)
      {
         nextPacDir = 3;
      }
      else if(playing && (Key.getCode() == 80 || Key.getCode() == 112))
      {
         if(Ready._visible)
         {
            Ready._visible = false;
            Ready.gotoAndStop(1);
            if(notMute)
            {
               startBGSnd();
            }
            if(!stopped)
            {
               Pacman.play();
            }
            play();
         }
         else
         {
            stop();
            Ready.gotoAndStop("Paused");
            Ready._visible = true;
            stopAllSounds();
            Pacman.stop();
         }
      }
      else if(playing && (Key.getCode() == 81 || Key.getCode() == 113 || Key.getCode() == 27))
      {
         quitting = true;
         stop();
         Ready.gotoAndStop("Quit");
         Ready._visible = true;
         stopAllSounds();
         Pacman.stop();
      }
      else if(quitting && (Key.getCode() == 78 || Key.getCode() == 110))
      {
         quitting = false;
         Ready._visible = false;
         Ready.gotoAndStop(1);
         if(notMute)
         {
            startBGSnd();
         }
         if(!stopped)
         {
            Pacman.play();
         }
         play();
      }
      else if(quitting && (Key.getCode() == 89 || Key.getCode() == 121))
      {
         quit = true;
         play();
      }
      else if(playing && !Ready._visible && (Key.getCode() == 77 || Key.getCode() == 109))
      {
         notMute = !notMute;
         if(notMute)
         {
            startBGSnd();
         }
         else
         {
            stopAllSounds();
         }
      }
      else if(Key.getCode() == 76 || Key.getCode() == 108)
      {
         toggleHighQuality();
      }
   }
}
