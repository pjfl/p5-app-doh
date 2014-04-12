Date.extend( 'nowMET', function() { // Calculate Middle European Time UTC + 1
   var now = new Date();

   now.setTime( now.getTime() + (now.getTimezoneOffset() + 60) * 60 * 1000 );

   return now;
} );

Date.extend( 'nowUTC', function() { // Calculate UTC
   var now = new Date();

   now.setTime( now.getTime() + now.getTimezoneOffset() * 60 * 1000 );

   return now;
} );

Date.implement( {
   dayFraction: function() { // Elapsed time since SOD in thousandths of a day
      return ( this.getHours() * 3600 + this.getMinutes() * 60
               + this.getSeconds() ) / 86.4;
   },

   swatchTime: function() {
      var met_day_fraction = Date.nowMET().dayFraction();

      return Number.from( met_day_fraction ).format( { decimals: 2 } );
   }
} );

Options.implement( {
   aroundSetOptions: function( options ) {
      options         = options || {};
      this.collection = [];
      this.context    = {};
      this.debug      = false;
      this.log        = function() {};

      [ 'config', 'context', 'debug' ].each( function( attr ) {
         if (options[ attr ] != undefined) {
            this[ attr ] = options[ attr ]; delete options[ attr ];
         }
      }.bind( this ) );

      this.setOptions( options ); var opt = this.options;

      if (! this.config && this.context.config && opt.config_attr)
         this.config = this.context.config[ opt.config_attr ];

      if (! this.config) this.config = {};

      if (this.context.collect) this.context.collect( this );

      if (this.context.window && this.context.window.logger)
         this.log = this.context.window.logger

      return this;
   },

   build: function() {
      var selector = this.options.selector;

      if (selector) $$( selector ).each( function( el ) {
         if (! this.collection.contains( el )) {
            this.collection.include( el ); this.attach( el );
         }
      }, this );
   },

   mergeOptions: function( arg ) {
      arg = arg || 'default';

      if (typeOf( arg ) != 'object') { arg = this.config[ arg ] || {} }

      return Object.merge( Object.clone( this.options ), arg );
   }
} );

String.implement( {
   escapeHTML: function() {
      var text = this;
      text = text.replace( /\&/g, '&amp;'  );
      text = text.replace( /\>/g, '&gt;'   );
      text = text.replace( /\</g, '&lt;'   );
      text = text.replace( /\"/g, '&quot;' );
      return text;
   },

   pad: function( length, str, direction ) {
      if (this.length >= length) return this;

      var pad = (str == null ? ' ' : '' + str)
         .repeat( length - this.length )
         .substr( 0, length - this.length );

      if (!direction || direction == 'right') return this + pad;
      if (direction == 'left') return pad + this;

      return pad.substr( 0, (pad.length / 2).floor() )
           + this + pad.substr( 0, (pad.length / 2).ceil() );
   },

   repeat: function( times ) {
      return new Array( times + 1 ).join( this );
   },

   unescapeHTML: function() {
      var text = this;
      text = text.replace( /\&amp\;/g,    '&' );
      text = text.replace( /\&dagger\;/g, '\u2020' );
      text = text.replace( /\&gt\;/g,     '>' );
      text = text.replace( /\&hellip\;/g, '\u2026' );
      text = text.replace( /\&lt\;/g,     '<' );
      text = text.replace( /\&nbsp\;/g,   '\u00a0' );
      text = text.replace( /\&\#160\;/g,  '\u00a0' );
      text = text.replace( /\&quot\;/g,   '"' );
      return text;
   }
} );

var Behaviour = new Class( {
   Implements: [ Events, Options ],

   config: {
      anchors: {}
   },

   options           : {
      baseURL        : null,
      firstField     : null,
      popup          : false,
      statusUpdPeriod: 4320,
      target         : null
   },

   initialize: function( options ) {
      this.setOptions( options ); this.collection = [];

      this.resize(); this.attach();
   },

   attach: function() {
      var cblocks, el, opt = this.options, prefs;

      if ((prefs = document.forms[ 'preferences' ])
          && (cblocks = $( prefs.code_blocks ))) {
         this.setCodeBlockClass( cblocks.value );

         if (prefs.mode && prefs.mode.value == 'static') {
            cblocks.addEvent( 'change', function( ev ) {
               ev.stop(); this.setCodeBlockClass( cblocks.value );
            }, this );
         }
         else {
            cblocks.addEvent( 'change', function( ev ) {
               ev.stop(); prefs.submit();
            } );
         }
      }

      $$( '.aj-nav' ).each( function( el ) {
         el.addEvent( 'click', function( ev ) {
            ev.stop();
            this.getParent().getSiblings().getElements( 'ul' )
                .each( function( list ) { list.dissolve() } );
            this.getNext().reveal();
         } );
      } );

      if (el = $( 'menu-spinner-button' )) {
         el.addEvent( 'click', function( ev ) {
            ev.stop(); $( 'sub-nav-collapse' ).toggle();
         } );
      }

      if (opt.statusUpdPeriod && !opt.popup)
         this.statusUpdater.periodical( opt.statusUpdPeriod, this );

      window.addEvent( 'load',   function() {
         this.load( opt.firstField ) }.bind( this ) );

      window.addEvent( 'resize', function() { this.resize() }.bind( this ) );
   },

   collect: function( object ) {
      this.collection.include( object ); return object;
   },

   load: function( first_field ) {
      var el, opt = this.options;

      this.window       = new WindowUtils( {
         context        : this,
         target         : opt.target,
         url            : opt.baseURL } );
      this.replacements = new Replacements( { context: this } );
      this.linkFade     = new LinkFader( { context: this } );
      this.tips         = new Tips( {
         context        : this,
         onHide         : function() { this.fx.start( 0 ) },
         onInitialize   : function() {
            this.fx     = new Fx.Tween( this.tip, {
               duration : 500,
               link     : 'chain',
               onChainComplete: function() {
                  if (this.tip.getStyle( 'opacity' ) == 0)
                      this.tip.setStyle( 'visibility', 'hidden' );
               }.bind( this ),
               property : 'opacity' } ).set( 0 ); },
         onShow         : function() {
            this.tip.setStyle( 'visibility', 'visible' ); this.fx.start( 1 ) },
         showDelay      : 666 } );

      if (first_field && (el = $( first_field ))) el.focus();
   },

   rebuild: function() {
      this.collection.each( function( object ) { object.build() } );
   },

   resize: function() {
      var nav, ribbon = $( 'github-ribbon' ), w = window.getWidth();

      if (w >= 768) {
         if (ribbon) ribbon.setStyle( 'right', '16px' );

         if (nav = $( 'sub-nav-collapse' )) nav.removeProperty( 'style' );
      }
      else {
         if (ribbon) ribbon.setStyle( 'right', '0px' );
      }
   },

   setCodeBlockClass: function( val ) {
      var article = $$( '.content-page article' ), rcol = $$( '.right-column' );

      if (article && rcol) {
         var code = article.getElements( 'pre' );

         if      (val == 1) {
            code.each( function( el ) { el.removeClass( 'hidden' ) } );
            rcol.each( function( el ) { el.addClass( 'float-view' ) } );
         }
         else if (val == 2) {
            code.each( function( el ) { el.removeClass( 'hidden' ) } );
            rcol.each( function( el ) { el.removeClass( 'float-view' ) } );
         }
         else if (val == 3) {
            code.each( function( el ) { el.addClass( 'hidden' ) } );
         }
      }
   },

   statusUpdater: function() {
      var h = window.getHeight(), w = window.getWidth();

      var swatch_time = Date.swatchTime();

      window.defaultStatus = 'w: ' + w + ' h: ' + h + ' @' + swatch_time;
   }
} );

var Dialog = new Class( {
   Implements: [ Options ],

   Binds: [ '_keyup' ],

   options: {
      klass   : 'dialog',
      maskOpts: {},
      title   : 'Options',
      useMask : true,
   },

   initialize: function( el, body, options ) {
      this.setOptions( options ); this.attach( this.create( el, body ) );
   },

   attach: function( el ) {
      el.addEvent( 'click', function( ev ) {
         ev.stop(); this.hide() }.bind( this ) );
      window.addEvent( 'keyup', this._keyup );
   },

   create: function( el, body ) {
      var opt = this.options;

      if (opt.useMask) this.mask = new Mask( el, opt.maskOpts );

      this.parent = this.mask ? this.mask.element : $( document.body );
      this.dialog = new Element( 'div', { 'class': opt.klass } ).hide()
          .inject( this.parent );

      var title   = new Element( 'div', { 'class': opt.klass + '-title' } )
          .appendText( opt.title ).inject( this.dialog );

      this.close  = new Element( 'span', { 'class': opt.klass + '-close' } )
          .appendText( 'x' ).inject( title );

      body.addClass( opt.klass + '-body' ).inject( this.dialog );
      return this.close;
   },

   hide: function() {
      this.visible = false; this.dialog.hide(); if (this.mask) this.mask.hide();
   },

   position: function() {
      this.dialog.position( { relativeTo: this.parent } );
   },

   show: function() {
      if (this.mask) this.mask.show();

      this.position(); this.dialog.show(); this.visible = true;
   },

   _keyup: function( ev ) {
      ev = new Event( ev ); ev.stop();

      if (this.visible && (ev.key == 'esc')) this.hide();
   }
} );

var LinkFader = new Class( {
   Implements: [ Options ],

   options    : {
      fc      : 'ff0000', // Fade to colour
      inBy    : 6,        // Fade in colour inc/dec by
      outBy   : 6,        // Fade out colour inc/dec by
      selector: '.fade',  // Class name matching links to fade
      speed   : 20        // Millisecs between colour changes
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();
   },

   attach: function( el ) {
      el.addEvent( 'mouseover', this.startFade.bind( this, el ) );
      el.addEvent( 'mouseout',  this.clearFade.bind( this, el ) );
   },

   clearFade: function( el ) {
      if (el.timer) clearInterval( el.timer );

      el.timer = this.fade.periodical( this.options.speed, this, [ el, 0 ] );
   },

   currentColour: function( el ) {
      var cc = el.getStyle( 'color' ), temp = '';

      if (cc.length == 4 && cc.substring( 0, 1 ) == '#') {
         for (var i = 0; i < 3; i++) {
            temp += cc.substring( i + 1, i + 2 ) + cc.substring( i + 1, i + 2);
         }

         cc = temp;
      }
      else if (cc.indexOf('rgb') != -1) { cc = cc.rgbToHex().substring(1, 7) }
      else if (cc.length == 7)          { cc = cc.substring( 1, 7 ) }
      else                              { cc = this.options.fc }

      return cc;
   },

   fade: function( el, d ) {
      var cc = this.currentColour( el ).hexToRgb( true );
      var tc = (d == 1)  ? this.options.fc.hexToRgb( true )
             : el.colour ? el.colour.hexToRgb( true )
                         : [ 0, 0, 0 ];

      if (tc[ 0 ] == cc[ 0 ] && tc[ 1 ] == cc[ 1 ] && tc[ 2 ] == cc[ 2 ]) {
         clearInterval( el.timer ); el.timer = null; return;
      }

      el.setStyle( 'color', this.nextColour( tc, cc, d ) );
   },

   nextColour: function( tc, cc, d ) {
      var change = (d == 1) ? this.options.inBy : this.options.outBy;
      var colour;

      for (var i = 0; i < 3; i++) {
         var diff, nc = cc[ i ];

         if (! colour) colour = 'rgb(';
         else colour += ',';

         if (tc[ i ]-cc[ i ] > 0) { diff   = tc[ i ] - cc[ i ] }
         else                     { diff   = cc[ i ] - tc[ i ] }
         if (diff  < change)      { change = diff }
         if (cc[ i ] > tc[ i ])   { nc     = cc[ i ] - change }
         if (cc[ i ] < tc[ i ])   { nc     = cc[ i ] + change }
         if (nc    < 0)           { nc     = 0 }
         if (nc    > 255)         { nc     = 255 }

         colour += nc;
      }

      colour += ')';
      return colour;
   },

   startFade: function( el ) {
      if (el.timer) {
         clearInterval( el.timer ); el.timer = null;

         if (el.colour) el.setStyle( 'color', el.colour.hexToRgb() );
      }

      el.colour = this.currentColour( el );
      el.timer  = this.fade.periodical( this.options.speed, this, [ el, 1 ] );
   }
} );

var LoadMore = new Class( {
   attach: function( el ) {
      var cfg; if (! (cfg = this.config[ el.id ])) return;

      var event = cfg.event || 'click';

      if (event == 'load') {
         this[ cfg.method ].apply( this, cfg.args ); return;
      }

      el.addEvent( event, function( ev ) {
         ev.stop(); this[ cfg.method ].apply( this, cfg.args ) }.bind( this ) );
   },

   request: function( url, id, val, on_complete ) {
      if (on_complete) this.onComplete = on_complete;

      if (url.substring( 0, 4 ) != 'http') url = this.options.url + url;

      new Request( { 'onSuccess': this._response.bind( this ), 'url': url } )
             .get( { 'content-type': 'text/xml', 'id': id, 'val': val } );
   },

   _response: function( text, xml ) {
      var doc = xml.documentElement; var html = this._unpack_items( doc );

      $( doc.getAttribute( 'id' ) ).set( 'html', html.unescapeHTML() );

      $$( doc.getElementsByTagName( 'script' ) ).each( function( item ) {
         var text = '';

         for (var i = 0, il = item.childNodes.length; i < il; i++) {
            text += item.childNodes[ i ].nodeValue;
         }

         if (text) Browser.exec( text );
      } );

      if (this.onComplete) this.onComplete.call( this.context, doc, html );
   },

   _unpack_items: function( doc ) {
      var html = '';

      $$( doc.getElementsByTagName( 'items' ) ).each( function( item ) {
         for (var i = 0, il = item.childNodes.length; i < il; i++) {
            html += item.childNodes[ i ].nodeValue;
         }
      } );

      return html;
   }
} );

var Replacements = new Class( {
   Implements: [ Options ],

   options              : {
      textarea_container: 'expanding_area',
      textarea_preformat: 'expanding_spacer',
      config_attr       : 'inputs',
      event             : 'click',
      method            : 'toggle',
      selector          : [ '.autosize', 'input[type=checkbox]',
                            'input[type=password].reveal',
                            'input[type=radio]' ],
      suffix            : '_replacement'
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();
   },

   build: function() {
      this.options.selector.each( function( selector ) {
         $$( selector ).each( function( el ) {
            if (! el.id) { $uid( el ); el.id = el.type + el.uid }

            if (! this.collection.contains( el.id )) {
               this.collection.include( el.id ); this.createMarkup( el );
            }

            this.attach( el );
         }, this );
      }, this );
   },

   createMarkup: function( el ) {
      var opt = this.mergeOptions( el.id ), new_id = el.id + opt.suffix;

      if (el.type == 'checkbox' || el.type == 'radio') {
         el.setStyles( { position: 'absolute', left: '-9999px' } );
         new Element( 'span', {
            'class': 'checkbox' + (el.checked ? ' checked' : ''),
            id     : new_id,
            name   : el.name
         } ).inject( el, 'after' );
         return;
      }

      if (el.type == 'textarea') {
         var div  = new Element( 'div',  { 'class': opt.textarea_container } );
         var pre  = new Element( 'pre',  { 'class': opt.textarea_preformat } );
         var span = new Element( 'span', { id: new_id } );

         div.inject( el, 'before' ); pre.inject( div ); div.grab( el );
         span.inject( pre ); new Element( 'br' ).inject( pre );
         span.set( 'text', el.value );
      }

      return;
   },

   attach: function( el ) {
      var opt = this.mergeOptions( el.id );

      if (el.type == 'textarea') {
         this._add_events( el, el, 'keyup', 'set_text' );
      }
      else {
         var replacement = $( el.id + opt.suffix ) || el;

         this._add_events( el, replacement, opt.event, opt.method );
      }
   },

   _add_events: function( el, replacement, events, methods ) {
      methods = Array.from( methods );

      Array.from( events ).each( function( event, index ) {
         var handler, key = 'event:' + event;

         if (! (handler = replacement.retrieve( key ))) {
            handler = function( ev ) {
               ev.stop(); this[ methods[ index ] ].call( this, el );
            }.bind( this );
            replacement.store( key, handler );
         }

         replacement.addEvent( event, handler );
      }, this );
   },

   hide_password: function( el ) {
      el.setProperty( 'type', 'password' );
   },

   set_text: function( el ) {
      var opt = this.mergeOptions( el.id );

      $( el.id + opt.suffix ).set( 'text', el.value );
   },

   show_password: function( el ) {
      el.setProperty( 'type', 'text' );
   },

   toggle: function( el ) {
      var opt         = this.mergeOptions( el.id );
      var replacement = $( el.id + opt.suffix );

      if (el.getProperty( 'disabled' )) return;

      replacement.toggleClass( 'checked' );

      if (replacement.hasClass( 'checked' )) {
         el.setProperty( 'checked', 'checked' );

         if (el.type == 'radio') {
            this.collection.each( function( box_id ) {
               var box = $( box_id ), replacement = $( box_id + opt.suffix );

               if (replacement && box_id != el.id && box.name == el.name
                   && replacement.hasClass( 'checked' )) {
                  replacement.removeClass ( 'checked' );
                  box.removeProperty( 'checked' );
               }
            }, this );
         }
      }
      else el.removeProperty( 'checked' );
   }
} );

/* Description: Class for creating nice tips that follow the mouse cursor
                when hovering an element.
   License: MIT-style license
   Authors: Valerio Proietti, Christoph Pojer, Luis Merino, Peter Flanigan */

(function() {

var getText = function( el ) {
   return (el.get( 'rel' ) || el.get( 'href' ) || '').replace( 'http://', '' );
};

var read = function( el, opt ) {
   return opt ? (typeOf( opt ) == 'function' ? opt( el ) : el.get( opt )) : '';
};

var storeTitleAndText = function( el, opt ) {
   if (el.retrieve( 'tip:title' )) return;

   var title = read( el, opt.title ), text = read( el, opt.text );

   if (title) {
      el.store( 'tip:native', title ); var pair = title.split( opt.separator );

      if (pair.length > 1) {
         title = pair[ 0 ].trim(); text = (pair[ 1 ] + ' ' + text).trim();
      }
   }
   else title = opt.hellip;

   if (title.length > opt.maxTitleChars)
      title = title.substr( 0, opt.maxTitleChars - 1 ) + opt.hellip;

   el.store( 'tip:title', title ).erase( 'title' );
   el.store( 'tip:text',  text  );
};

this.Tips = new Class( {
   Implements: [ Events, Options ],

   options         : {
      className    : 'tips',
      fixed        : false,
      fsWidthRatio : 1.35,
      hellip       : '\u2026',
      hideDelay    : 100,
      id           : 'tips',
      maxTitleChars: 40,
      maxWidthRatio: 4,
      minWidth     : 120,
      offsets      : { x: 4, y: 36 },
/*    onAttach     : function( el ) {}, */
/*    onBound      : function( coords ) {}, */
/*    onDetach     : function( el) {}, */
      onHide       : function( tip, el ) {
         tip.setStyle( 'visibility', 'hidden'  ) },
      onShow       : function( tip, el ) {
         tip.setStyle( 'visibility', 'visible' ) },
      selector     : '.tips',
      separator    : '~',
      showDelay    : 100,
      showMark     : true,
      spacer       : '\u00a0\u00a0\u00a0',
      text         : getText,
      timeout      : 30000,
      title        : 'title',
      windowPadding: { x: 0, y: 0 }
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.createMarkup();

      this.build(); this.fireEvent( 'initialize' );
   },

   attach: function( el ) {
      var opt = this.options; storeTitleAndText( el, opt );

      var events = [ 'enter', 'leave' ]; if (! opt.fixed) events.push( 'move' );

      events.each( function( value ) {
         var key = 'tip:' + value, method = 'element' + value.capitalize();

         var handler; if (! (handler = el.retrieve( key )))
            el.store( key, handler = function( ev ) {
               return this[ method ].apply( this, [ ev, el ] ) }.bind( this ) );

         el.addEvent( 'mouse' + value, handler );
      }, this );

      this.fireEvent( 'attach', [ el ] );
   },

   createMarkup: function() {
      var opt    = this.options;
      var klass  = opt.className;
      var dlist  = this.tip = new Element( 'dl', {
         'id'    : opt.id,
         'class' : klass + '-container',
         'styles': { 'left'      : 0,
                     'position'  : 'absolute',
                     'top'       : 0,
                     'visibility': 'hidden' } } ).inject( document.body );

      if (opt.showMark) {
         this.mark = []; [ 0, 1 ].each( function( idx ) {
            var el = this.mark[ idx ] = new Element( 'span', {
               'class': klass + '-mark' + idx } ).inject( dlist );

            [ 'left', 'top' ].each( function( prop ) {
               el.store( 'tip:orig-' + prop, el.getStyle( prop ) ) } );
         }, this );
      }

      this.term = new Element( 'dt', {
         'class' : klass + '-term' } ).inject( dlist );
      this.defn = new Element( 'dd', {
         'class' : klass + '-defn' } ).inject( dlist );
   },

   detach: function() {
      this.collection.each( function( el ) {
         [ 'enter', 'leave', 'move' ].each( function( value ) {
            var ev = 'mouse' + value, key = 'tip:' + value;

            el.removeEvent( ev, el.retrieve( key ) ).eliminate( key );
         } );

         this.fireEvent( 'detach', [ el ] );

         if (this.options.title == 'title') {
            var original = el.retrieve( 'tip:native' );

            if (original) el.set( 'title', original );
         }
      }, this );

      return this;
   },

   elementEnter: function( ev, el ) {
      clearTimeout( this.timer );
      this.timer = this.show.delay( this.options.showDelay, this, el );
      this.setup( el ); this.position( ev, el );
   },

   elementLeave: function( ev, el ) {
      clearTimeout( this.timer );

      var opt = this.options, delay = Math.max( opt.showDelay, opt.hideDelay );

      this.timer = this.hide.delay( delay, this, el );
      this.fireForParent( ev, el );
   },

   elementMove: function( ev, el ) {
      this.position( ev, el );
   },

   fireForParent: function( ev, el ) {
      el = el.getParent(); if (! el || el == document.body) return;

      if (el.retrieve( 'tip:enter' )) el.fireEvent( 'mouseenter', ev );
      else this.fireForParent( ev, el );
   },

   hide: function( el ) {
      this.fireEvent( 'hide', [ this.tip, el ] );
   },

   position: function( ev, el ) {
      var opt    = this.options;
      var bounds = opt.fixed ? this._positionFixed( ev, el )
                             : this._positionVariable( ev, el );

      if (opt.showMark) this._positionMarks( bounds );
   },

   _positionFixed: function( ev, el ) {
      var offsets = this.options.offsets, pos = el.getPosition();

      this.tip.setStyles( { left: pos.x + offsets.x, top: pos.y + offsets.y } );

      return { x: false, x2: false, y: false, y2: false };
   },

   _positionMark: function( state, quads, coord, dimn ) {
      for (var idx = 0; idx < 2; idx++) {
         var el     = this.mark[ idx ];
         var colour = el.getStyle( 'border-' + quads[ 0 ] + '-color' );

         if (colour != 'transparent') {
            el.setStyle( 'border-' + quads[ 0 ] + '-color', 'transparent' );
            el.setStyle( 'border-' + quads[ 1 ] + '-color', colour );
         }

         var orig  = el.retrieve( 'tip:orig-' + coord ).toInt();
         var value = this.tip.getStyle( dimn ).toInt();

         if (coord == 'left') {
            var blsize = this.tip.getStyle( 'border-left' ).toInt();
            var left   = this.mark[ 0 ].retrieve( 'tip:orig-left' ).toInt();

            value -= 2 * left - blsize * idx;
         }

         el.setStyle( coord, (state ? value : orig) + 'px' );
      }
   },

   _positionMarks: function( coords ) {
      var quads = coords[ 'x2' ] ? [ 'left', 'right' ] : [ 'right', 'left' ];

      this._positionMark( coords[ 'x2' ], quads, 'left', 'width' );

      quads = coords[ 'y2' ] ? [ 'bottom', 'top' ] : [ 'top', 'bottom' ];

      this._positionMark( coords[ 'y2' ], quads, 'top', 'height' );
   },

   _positionVariable: function( ev, el ) {
      var opt     = this.options, offsets = opt.offsets, pos = {};
      var prop    = { x: 'left',                 y: 'top'                 };
      var scroll  = { x: window.getScrollLeft(), y: window.getScrollTop() };
      var tip     = { x: this.tip.offsetWidth,   y: this.tip.offsetHeight };
      var win     = { x: window.getWidth(),      y: window.getHeight()    };
      var bounds  = { x: false, x2: false,       y: false, y2: false      };
      var padding = opt.windowPadding;

      for (var z in prop) {
         var coord = ev.page[ z ] + offsets[ z ];

         if (coord < 0) bounds[ z ] = true;

         if (coord + tip[ z ] > scroll[ z ] + win[ z ] - padding[ z ]) {
            coord = ev.page[ z ] - offsets[ z ] - tip[ z ];
            bounds[ z + '2' ] = true;
         }

         pos[ prop[ z ] ] = coord;
      }

      this.fireEvent( 'bound', bounds ); this.tip.setStyles( pos );

      return bounds;
   },

   setup: function( el ) {
      var opt    = this.options;
      var term   = el.retrieve( 'tip:title' ) || '';
      var defn   = el.retrieve( 'tip:text'  ) || '';
      var tfsize = this.term.getStyle( 'font-size' ).toInt();
      var dfsize = this.defn.getStyle( 'font-size' ).toInt();
      var max    = Math.floor( window.getWidth() / opt.maxWidthRatio );
      var w      = Math.max( term.length * tfsize / opt.fsWidthRatio,
                             defn.length * dfsize / opt.fsWidthRatio );

      w = parseInt( w < opt.minWidth ? opt.minWidth : w > max ? max : w );

      this.tip.setStyle( 'width', w + 'px' );
      this.term.empty().appendText( term || opt.spacer );
      this.defn.empty().appendText( defn || opt.spacer );
   },

   show: function( el ) {
      var opt = this.options;

      if (opt.timeout) this.timer = this.hide.delay( opt.timeout, this );

      this.fireEvent( 'show', [ this.tip, el ] );
   }
} );
} )();

var WindowUtils = new Class( {
   Implements: [ Options, LoadMore ],

   options       : {
      config_attr: 'anchors',
      customLogFn: false,
      height     : 600,
      quiet      : false,
      selector   : '.windows',
      target     : null,
      url        : null,
      width      : 800
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); var opt = this.options;

      if (opt.customLogFn) {
         if (typeOf( opt.customLogFn ) != 'function')
            throw 'customLogFn is not a function';
         else this.customLogFn = opt.customLogFn;
      }

      if (opt.target == 'top') this.placeOnTop();

      this.dialogs = [];
      this.build();
   },

   location: function( href ) {
      if (document.images) top.location.replace( href );
      else top.location.href = href;
   },

   logger: function( message ) {
      if (this.options.quiet) return;

      message = 'formwidgets.js: ' + message;

      if (this.customLogFn) { this.customLogFn( message ) }
      else if (window.console && window.console.log) {
         window.console.log( message );
      }
   },

   modalDialog: function( href, options ) {
      var opt = this.mergeOptions( options ), id = opt.name + '_dialog', dialog;

      if (! (dialog = this.dialogs[ opt.name ])) {
         var content = new Element( 'div', {
            'id': id } ).appendText( 'Loading...' );

         dialog = this.dialogs[ opt.name ]
                = new Dialog( undefined, content, opt );
      }

      this.request( href, id, opt.value || '', opt.onComplete || function() {
         this.rebuild(); dialog.show() } );

      return dialog;
   },

   openWindow: function( href, options ) {
      return new Browser.Popup( href, this.mergeOptions( options ) );
   },

   placeOnTop: function() {
      if (self != top) {
         if (document.images) top.location.replace( window.location.href );
         else top.location.href = window.location.href;
      }
   }
} );
