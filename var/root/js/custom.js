$( function() {
   var ribbon = $( '#github-ribbon' )[ 0 ];

   $( document ).ready( function() {
      if ($( window ).width() >= 768) {
         if (ribbon) ribbon.style.right = '16px';
      }

      var form; if (form = document.forms[ 'preferences' ] ) {
         var article = $( '.content-page article' );
         var rcol    = $( '.right-column' );

         if (article && rcol) {
            var val  = form.code_blocks.value;
            var code = article.children().filter( 'pre' );

            if      (val == 1) { code.addClass( 'hidden' ) }
            else if (val == 2) {
               code.removeClass( 'hidden' ); rcol.addClass( 'float-view' );
            }
            else if (val == 3) {
               code.removeClass( 'hidden' ); rcol.removeClass( 'float-view' );
            }
         }
      }
   } );

   $( window ).resize( function() {
      if ($( window ).width() >= 768) {
         if (ribbon) ribbon.style.right = '16px';
         // Remove transition inline style on large screens
         $( '#sub-nav-collapse' ).removeAttr( 'style' );
      }
      else {
         if (ribbon) ribbon.style.right = '0px';
      }
   } );

   $( '.aj-nav' ).click( function( ev ) {
      ev.preventDefault();
      $( this ).parent().siblings().find( 'ul' ).slideUp();
      $( this ).next().slideToggle();
   } );

   $( '#code_blocks' ).change( function( ev ) {
      ev.preventDefault(); document.forms[ 'preferences' ].submit();
   } );

   // Responsive menu spinner
   $( '#menu-spinner-button' ).click( function() {
      $( '#sub-nav-collapse' ).slideToggle();
   } );
} );
