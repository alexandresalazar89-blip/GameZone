stop();
Stage.showMenu = false;
this.onEnterFrame = function()
{
   var _loc1_ = this;
   sofar = _loc1_.getBytesLoaded();
   total = _loc1_.getBytesTotal();
   Bar._width = int(sofar / total * 100);
   if(sofar == total)
   {
      delete _loc1_.onEnterFrame;
      nextFrame();
   }
};
