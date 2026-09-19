on(press){
   page += 10;
   if(page > maxScore)
   {
      page = maxScore;
   }
   if(page > maxScore - 20)
   {
      next_btn._visible = false;
   }
   last_btn._visible = true;
   showScores();
}
