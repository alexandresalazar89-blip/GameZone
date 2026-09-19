_root.promo.html = true;
_root.promo.htmlText = _root.megaText;
String.prototype.addCommas = function()
{
   var _loc3_ = this.length;
   var _loc2_ = "";
   var _loc1_ = 0;
   while(_loc1_ <= _loc3_)
   {
      _loc2_ = this.charAt(_loc3_ - _loc1_) + _loc2_;
      if(_loc1_ % 3 == 0 && _loc1_ > 0 && _loc1_ < _loc3_)
      {
         _loc2_ = "," + _loc2_;
      }
      _loc1_ = _loc1_ + 1;
   }
   return _loc2_;
};
game_so = SharedObject.getLocal("neavePacman");
score = 0;
