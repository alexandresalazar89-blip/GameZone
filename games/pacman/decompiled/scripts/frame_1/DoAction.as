_root.loaderxml = new XML();
_root.loaderxml.ignoreWhite = true;
_root.megaText = "";
trace(loaderxml);
_root.loaderxml.onLoad = function(suc)
{
   var _loc1_ = _root;
   if(suc)
   {
      _loc1_.megaText = _loc1_.loaderxml.firstChild.firstChild.firstChild.nodeValue;
      trace(_loc1_.megaText);
      _loc1_.promo.html = true;
      _loc1_.promo.htmlText = _loc1_.megaText;
   }
};
_root.loaderxml.onHTTPStatus = function(val)
{
};
_root.loaderxml.load(promourl);
