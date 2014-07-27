/* Editor - https://github.com/lepture/editor
 * MIT. Copyright (c) 2013 - 2014 by Hsiaoming Yang */
(function( window, document ) {
var isMac     = /Mac/.test( navigator.platform );
var shortcuts = {
   'bold'          : [ 'Cmd-B',     toggleBold ],
   'codeblock'     : [ '',          insertGraves,        'Code block' ],
   'fullscreen'    : [ '',          toggleFullScreen,    'Full screen mode' ],
   'h2'            : [ 'Cmd-H',     toggleH2,            'Heading level 2' ],
   'h3'            : [ 'Cmd-Alt-H', toggleH3,            'Heading level 3' ],
   'image'         : [ 'Cmd-Alt-I', insertImage ],
   'italic'        : [ 'Cmd-I',     toggleItalic ],
   'link'          : [ 'Cmd-K',     insertLink ],
   'ordered-list'  : [ 'Cmd-Alt-L', toggleOrderedList,   'Ordered list' ],
   'quote'         : [ "Cmd-'",     toggleBlockquote,    'Block quote' ],
   'redo'          : [ '',          redo,                'Redo last' ],
   'undo'          : [ '',          undo,                'Undo previous' ],
   'unordered-list': [ 'Cmd-L',     toggleUnOrderedList, 'Unordered list' ]
};
var toolbar   = [
   { name: 'h2', action: toggleH2 },
   { name: 'h3', action: toggleH3 },
   { name: 'bold', action: toggleBold },
   { name: 'italic', action: toggleItalic },
   '|',
   { name: 'quote', action: toggleBlockquote },
   { name: 'unordered-list', action: toggleUnOrderedList },
   { name: 'ordered-list', action: toggleOrderedList },
   '|',
   { name: 'link', action: insertLink },
   { name: 'image', action: insertImage },
   { name: 'codeblock', action: insertGraves },
   '|',
   { name: 'undo', action: undo },
   { name: 'redo', action: redo },
   { name: 'fullscreen', action: toggleFullScreen }
];

function _createIcon( name, options ) {
   options = options || {};

   var el = document.createElement( 'a' );
   var shortcut = options.shortcut || shortcuts[ name ];

   if (shortcut) {
      el.title = _fixShortcut( (shortcut[ 0 ] || '...') )
               + ' ~ ' + (shortcut[ 2 ] || name.ucfirst());
      el.title = el.title.replace( 'Cmd', '⌘' );

      if (isMac) el.title = el.title.replace( 'Alt', '⌥' );
   }

   el.className = (options.className || 'icon-' + name) + ' tips';
   return el;
}

function _createSep() {
   el = document.createElement( 'i' );
   el.className = 'separator';
   el.innerHTML = '|';
   return el;
}

function _fixShortcut( name ) {
   if (isMac) name = name.replace( 'Ctrl', 'Cmd' );
   else name = name.replace( 'Cmd', 'Ctrl' );

   return name;
}

function _getState( cm, pos ) {
   pos = pos || cm.getCursor( 'from' );

   var stat = cm.getTokenAt( pos, true ); if (!stat.type) return {};

   var types = stat.type.split( ' ' ), ret = {}, data, text;

   for (var i = 0, tl = types.length; i < tl; i++) {
      data = types[ i ];

      if      (data === 'strong') ret.bold = true;
      else if (data === 'variable-2') {
         text = cm.getLine( pos.line );

         if (/^\s*\d+\.\s/.test( text )) ret[ 'ordered-list' ] = true;
         else ret[ 'unordered-list' ] = true;
      }
      else if (data === 'code') ret.codeblock = true;
      else if (data === 'atom') ret.quote = true;
      else if (data === 'em') ret.italic = true;
   }

   return ret;
}

function _replaceSelection( cm, active, start, end ) {
   var startPoint = cm.getCursor( 'from' ), endPoint = cm.getCursor( 'to' );
   var text;

   if (active) {
      text  = cm.getLine( startPoint.line );
      start = text.slice( 0, startPoint.ch );
      end   = text.slice( endPoint.ch );
      cm.setLine( startPoint.line, start + end );
   }
   else {
      text = cm.getSelection();
      cm.replaceSelection( start + text + end );
      startPoint.ch += start.length;

      if (startPoint !== endPoint) endPoint.ch += start.length;
   }

   cm.setSelection( startPoint, endPoint );
   cm.focus();
}

function _toggleLine( cm, name ) {
   var stat       = _getState( cm );
   var startPoint = cm.getCursor( 'from' );
   var endPoint   = cm.getCursor( 'to' );
   var repl = {
      'h2'            : /^(\s*)\#\#\s+/,
      'h3'            : /^(\s*)\#\#\#\s+/,
      'quote'         : /^(\s*)\>\s+/,
      'unordered-list': /^(\s*)(\*|\-|\+)\s+/,
      'ordered-list'  : /^(\s*)\d+\.\s+/
   };
   var map = {
      'h2'            : '## ',
      'h3'            : '### ',
      'quote'         : '> ',
      'unordered-list': '* ',
      'ordered-list'  : '1. '
   };

   for (var i = startPoint.line; i <= endPoint.line; i++) {
      (function( i ) {
         var text = cm.getLine( i );

         if (stat[ name ]) text = text.replace( repl[ name ], '$1' );
         else text = map[ name ] + text;

         cm.setLine( i, text );
      } )( i );
   }

   cm.focus();
}

function _wordCount( data ) {
   var pattern = /[a-zA-Z0-9_\u0392-\u03c9]+|[\u4E00-\u9FFF\u3400-\u4dbf\uf900-\ufaff\u3040-\u309f\uac00-\ud7af]+/g;
   var m = data.match( pattern ), count = 0;

   if (m === null) return count;

   for (var i = 0, ml = m.length; i < ml; i++) {
      if (m[ i ].charCodeAt( 0 ) >= 0x4E00) count += m[ i ].length;
      else count += 1;
   }

   return count;
}

function insertGraves( editor ) {
   var cm = editor.codemirror, stat = _getState( cm );

   _replaceSelection( cm, stat.code, '```', '```' );
}

function insertImage( editor ) {
   var cm = editor.codemirror, stat = _getState( cm );

   _replaceSelection( cm, stat.image, '![', '](http://)' );
}

function insertLink( editor ) {
   var cm = editor.codemirror, stat = _getState( cm );

   _replaceSelection( cm, stat.link, '[', '](http://)' );
}

function redo( editor ) {
   var cm = editor.codemirror; cm.redo(); cm.focus();
}

function toggleBlockquote( editor ) {
   var cm = editor.codemirror; _toggleLine( cm, 'quote' );
}

function toggleBold( editor ) {
   var cm         = editor.codemirror;
   var stat       = _getState( cm );
   var startPoint = cm.getCursor( 'from' );
   var endPoint   = cm.getCursor( 'to' );
   var start      = '**';
   var end        = '**';
   var text;

   if (stat.bold) {
      text  = cm.getLine( startPoint.line );
      start = text.slice( 0, startPoint.ch );
      end   = text.slice( startPoint.ch );
      start = start.replace( /^(.*)?(\*|\_){2}(\S+.*)?$/, '$1$3' );
      end   = end.replace( /^(.*\S+)?(\*|\_){2}(\s+.*)?$/, '$1$3' );
      startPoint.ch -= start.length;

      if (startPoint !== endPoint) endPoint.ch -= start.length;

      cm.setLine( startPoint.line, start + end );
   }
   else {
      text = cm.getSelection();
      cm.replaceSelection( start + text + end );
      startPoint.ch += start.length;

      if (startPoint !== endPoint) endPoint.ch += start.length;
   }

   cm.setSelection( startPoint, endPoint );
   cm.focus();
}

/* https://developer.mozilla.org/en-US/docs/DOM/Using_fullscreen_mode */
function toggleFullScreen( editor ) {
   var el      = editor.codemirror.getWrapperElement();
   var doc     = document;
   var isFull  = doc.fullScreen || doc.mozFullScreen || doc.webkitFullScreen;
   var request = function() {
      if      (el.requestFullScreen)    el.requestFullScreen();
      else if (el.mozRequestFullScreen) el.mozRequestFullScreen();
      else if (el.webkitRequestFullScreen) {
         el.webkitRequestFullScreen( Element.ALLOW_KEYBOARD_INPUT );
      }
   };
   var cancel = function() {
      if      (doc.cancelFullScreen)       doc.cancelFullScreen();
      else if (doc.mozCancelFullScreen)    doc.mozCancelFullScreen();
      else if (doc.webkitCancelFullScreen) doc.webkitCancelFullScreen();
   };

   if (!isFull) request();
   else if (cancel) cancel();
}

function toggleH2( editor ) {
   var cm = editor.codemirror; _toggleLine( cm, 'h2' );
}

function toggleH3( editor ) {
   var cm = editor.codemirror; _toggleLine( cm, 'h3' );
}

function toggleItalic( editor ) {
   var cm         = editor.codemirror;
   var stat       = _getState( cm );
   var startPoint = cm.getCursor( 'from' );
   var endPoint   = cm.getCursor( 'to' );
   var start      = '*';
   var end        = '*';
   var text;

   if (stat.italic) {
      text  = cm.getLine( startPoint.line );
      start = text.slice( 0, startPoint.ch );
      end   = text.slice( startPoint.ch );
      start = start.replace( /^(.*)?(\*|\_)(\S+.*)?$/, '$1$3' );
      end   = end.replace( /^(.*\S+)?(\*|\_)(\s+.*)?$/, '$1$3' );
      startPoint.ch -= start.length;

      if (startPoint !== endPoint) endPoint.ch -= start.length;

      cm.setLine( startPoint.line, start + end );
   }
   else {
      text = cm.getSelection();
      cm.replaceSelection( start + text + end );
      startPoint.ch += start.length;

      if (startPoint !== endPoint) endPoint.ch += start.length;
   }

   cm.setSelection( startPoint, endPoint );
   cm.focus();
}

function toggleOrderedList( editor ) {
   var cm = editor.codemirror; _toggleLine( cm, 'ordered-list' );
}

function toggleUnOrderedList( editor ) {
   var cm = editor.codemirror; _toggleLine( cm, 'unordered-list' );
}

function undo( editor ) {
   var cm = editor.codemirror; cm.undo(); cm.focus();
}

/* Interface of Editor */
function Editor( options ) {
   options = options || {};

   if (options.element) this.element = options.element;

   options.toolbar = options.toolbar || Editor.toolbar;
   // you can customize toolbar with object
   // [{name: 'bold', shortcut: 'Ctrl-B', className: 'icon-bold'}]
   if (!options.hasOwnProperty( 'status' )) {
      options.status = [ 'lines', 'words', 'cursor' ];
   }

   this.options = options;

   if (this.element) this.render();
}

Editor.toolbar = toolbar;

Editor.markdown = function( text ) { // Use marked as markdown parser
   if (window.marked) return marked( text );
};

Editor.prototype.createCodeMirror = function( el ) {
   var self = this, keyMaps = {};

   for (var key in shortcuts) {
      (function( tuple ) {
         if (tuple[ 0 ].length)
            keyMaps[ _fixShortcut( tuple[ 0 ] ) ]
               = function( cm ) { tuple[ 1 ]( self ) };
      } )( shortcuts[ key ] );
   }

   keyMaps[ 'Enter' ] = 'newlineAndIndentContinueMarkdownList';

   var codeMirrorOptions  = this.options.codeMirror || {};
   var codeMirrorDefaults = {
      extraKeys     : keyMaps,
      indentWithTabs: false,
      lineNumbers   : false,
      mode          : 'markdown',
      tabSize       : 3,
      theme         : 'paper'
   };

   for (var key in codeMirrorDefaults) {
      codeMirrorOptions[ key ] = codeMirrorOptions[ key ]
                              || codeMirrorDefaults[ key ];
   }

   this.codemirror = CodeMirror.fromTextArea( el, codeMirrorOptions );
};

Editor.prototype.createToolbar = function( items ) {
   items = items || this.options.toolbar;

   if (!items || items.length === 0) return;

   var bar  = document.createElement( 'div' ); bar.className = 'editor-toolbar';
   var self = this; self.toolbar = {};

   for (var i = 0, il = items.length; i < il; i++) {
      (function( item ) {
         var el;

         if      (item.name)    el = _createIcon( item.name, item );
         else if (item === '|') el = _createSep();
         else                   el = _createIcon( item );

         if (item.action) {
            if (typeof item.action === 'function') {
               el.onclick = function( e ) { item.action( self ); };
            }
            else if (typeof item.action === 'string') {
               el.href = item.action; el.target = '_blank';
            }
         }

         self.toolbar[ item.name || item ] = el; bar.appendChild( el );
      } )(items[ i ]);
   }

   var cm = this.codemirror;

   cm.on( 'cursorActivity', function() {
      var stat = _getState( cm );

      for (var key in self.toolbar) {
         (function( key ) {
            var el = self.toolbar[ key ];
            if (stat[key]) el.className += ' active';
            else el.className = el.className.replace( /\s*active\s*/g, '' );
         } )(key);
      }
   } );

   var cmWrapper = cm.getWrapperElement();

   cmWrapper.parentNode.insertBefore( bar, cmWrapper );
   return bar;
};

Editor.prototype.createStatusbar = function( status ) {
   status = status || this.options.status;

   if (!status || status.length === 0) return;

   var bar = document.createElement( 'div' ), cm = this.codemirror, pos;

   bar.className = 'editor-statusbar';

   for (var i = 0, sl = status.length; i < sl; i++) {
      (function( name ) {
         var el = document.createElement( 'span' ); el.className = name;

         if (name === 'words') {
            el.innerHTML = '0';
            cm.on( 'update', function() {
               el.innerHTML = wordCount( cm.getValue() );
            } );
         }
         else if (name === 'lines') {
            el.innerHTML = '0';
            cm.on( 'update', function() { el.innerHTML = cm.lineCount(); } );
         }
         else if (name === 'cursor') {
            el.innerHTML = '0:0';
            cm.on('cursorActivity', function() {
               pos = cm.getCursor(); el.innerHTML = pos.line + ':' + pos.ch;
            } );
         }

         bar.appendChild( el );
      } )(status[ i ]);
   }

   var cmWrapper = this.codemirror.getWrapperElement();

   cmWrapper.parentNode.insertBefore( bar, cmWrapper.nextSibling );
   return bar;
};

Editor.prototype.render = function( el ) {
   this.element = el || this.element
                     || document.getElementsByTagName( 'textarea' )[ 0 ];

   if (this._rendered && this._rendered === this.element) return;

   this.createCodeMirror( this.element );

   if (this.options.toolbar !== false) this.createToolbar();
   if (this.options.status  !== false) this.createStatusbar();

   this._rendered = this.element;
};

window.Editor = Editor;

})( window, document );
