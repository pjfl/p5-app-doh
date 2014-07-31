// Perl Artistic license except where stated otherwise

var Behaviour = new Class( {
   Implements: [ Events, Options ],

   config    : {
      anchors: {},
      inputs : {}
   },

   options           : {
      baseURL        : null,
      firstField     : null,
      formName       : null,
      message        : null,
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
            }.bind( this ) );
         }
         else {
            cblocks.addEvent( 'change', function( ev ) {
               ev.stop(); prefs.submit();
            } );
         }
      }

      $$( '.aj-nav' ).each( function( el ) {
         el.addEvent( 'click', function( ev ) {
            ev.stop(); var parent = this.getParent();

            parent.getParent().getSiblings().getElements( 'ul' )
                  .each( function( list ) { list.dissolve() } );
            parent.getNext().reveal();
         } );
      } );

      if (el = $( 'menu-spinner-button' )) {
         el.addEvent( 'click', function( ev ) {
            ev.stop(); $( 'sub-nav-collapse' ).toggle();
         } );
      }

      if (footer = $( 'fixed-footer' )) {
         var content = footer.getPrevious();
         var fill    = new Element( 'div', {
            class : 'footer-spacer forward-events', id: 'footer-spacer',
            styles: { height: footer.getSize().y } } )
            .inject( content, 'after' );
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
      this.submit       = new SubmitUtils( {
         context        : this,
         formName       : opt.formName } );
      this.forwarder    = new EventForwarding( { context: this } );
      this.headroom     = new Headroom( {
         classes        : {
            pinned      : 'navbar-fixed-top' },
         context        : this,
         offset         : 108,
         selector       : '.navbar',
         tolerance      : 10 } );
      this.noticeBoard  = new NoticeBoard( { context: this } );
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

      if (opt.message) this.noticeBoard.create( opt.message );

      if (first_field && (el = $( first_field ))) el.focus();
   },

   rebuild: function() {
      this.collection.each( function( object ) { object.build() } );
   },

   resize: function() {
      var footer, nav, ribbon = $( 'github-ribbon' ), w = window.getWidth();

      if (w >= 820) {
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
