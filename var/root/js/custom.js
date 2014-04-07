$( function() {
   var ribbon = $( '#github-ribbon' )[ 0 ];

   var setCodeBlockClass = function( val ) {
      var article = $( '.content-page article' ), rcol = $( '.right-column' );

      if (article && rcol) {
         var code = article.children().filter( 'pre' );

         if      (val == 1) {
            code.removeClass( 'hidden' ); rcol.addClass( 'float-view' );
         }
         else if (val == 2) {
            code.removeClass( 'hidden' ); rcol.removeClass( 'float-view' );
         }
         else if (val == 3) { code.addClass( 'hidden' ) }
      }
   };

   $( document ).ready( function() {
      if ($( window ).width() >= 768) {
         if (ribbon) ribbon.style.right = '16px';
      }

      var editor; if (editor = $( '#markdown-editor' )) editor.autosize();

      var prefs; if (prefs = document.forms[ 'preferences' ]) {
         var cblocks = prefs.code_blocks; setCodeBlockClass( cblocks.value );

         if (prefs.mode && prefs.mode.value == 'static') {
            $( '#code_blocks' ).change( function( ev ) {
               ev.preventDefault(); setCodeBlockClass( cblocks.value );
            } );
         }
         else {
            $( '#code_blocks' ).change( function( ev ) {
               ev.preventDefault(); prefs.submit();
            } );
         }
      }

      $( '.aj-nav' ).click( function( ev ) {
         ev.preventDefault();
         $( this ).parent().siblings().find( 'ul' ).slideUp();
         $( this ).next().slideToggle();
      } );

      $( '#menu-spinner-button' ).click( function() {
         $( '#sub-nav-collapse' ).slideToggle();
      } );
   } );

   $( window ).resize( function() {
      if ($( window ).width() >= 768) {
         if (ribbon) ribbon.style.right = '16px';

         $( '#sub-nav-collapse' ).removeAttr( 'style' );
      }
      else {
         if (ribbon) ribbon.style.right = '0px';
      }
   } );
} );
