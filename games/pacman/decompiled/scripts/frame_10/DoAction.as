stop();
showScores = function()
{
   var _loc2_ = 10;
   var _loc3_;
   var _loc1_;
   while(_loc2_ > 0)
   {
      _loc3_ = scoreboard_lv["name" + (page + _loc2_)];
      var s = scoreboard_lv["score" + (page + _loc2_)];
      _loc1_ = this["line" + _loc2_ + "_mc"];
      _loc1_.rank_txt.text = page + _loc2_ + ".";
      _loc1_.name_txt.text = !_loc3_.length ? "..." : _loc3_.toUpperCase();
      _loc1_.score_txt.text = !s.length ? "..." : s.addCommas();
      _loc1_.rank_txt.textColor = _loc1_.name_txt.textColor = _loc1_.score_txt.textColor = !(game_so.data.playerName.length && _loc3_.toUpperCase() == game_so.data.playerName.toUpperCase()) ? 16777215 : 16777011;
      _loc1_._visible = true;
      loading_mc._visible = false;
      _loc2_ = _loc2_ - 1;
   }
};
page = 0;
maxScore = 100;
scoreboard_lv = new LoadVars();
if(score > 0 && game_so.data.playerName.length > 0)
{
   scoreboard_lv.score = score;
   scoreboard_lv.name = game_so.data.playerName.toLowerCase();
}
scoreboard_lv.game = "pacman";
scoreboard_lv.sendAndLoad("http://www.neave.com/games/games_score_text.php",scoreboard_lv,"POST");
scoreboard_lv.onLoad = function(success)
{
   if(success)
   {
      if(Boolean(scoreboard_lv.success))
      {
         next_btn._visible = true;
         if(scoreboard_lv.maxScore.length > 0)
         {
            maxScore = Number(scoreboard_lv.maxScore);
         }
         showScores();
      }
      else
      {
         loading_mc.errorMsg = scoreboard_lv.errorMsg.toUpperCase();
         loading_mc.gotoAndStop(2);
      }
   }
   else
   {
      loading_mc.errorMsg = "COULD NOT ACCESS SCORES.";
      loading_mc.gotoAndStop(2);
   }
};
score = 0;
next_btn._visible = last_btn._visible = false;
