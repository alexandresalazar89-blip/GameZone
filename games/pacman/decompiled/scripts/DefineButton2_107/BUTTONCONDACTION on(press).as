on(press){
   page -= 10;
   if(page < 0)
   {
      page = 0;
   }
   if(page < 10)
   {
      last_btn._visible = false;
   }
   next_btn._visible = true;
   showScores();
}
