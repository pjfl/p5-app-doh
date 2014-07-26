/* Editor - https://github.com/lepture/editor
 * MIT. Copyright (c) 2013 - 2014 by Hsiaoming Yang */
(function( window ) {
var isMac     = /Mac/.test( navigator.platform );
var shortcuts = {
   'Cmd-B'    : toggleBold,
   'Cmd-I'    : toggleItalic,
   'Cmd-K'    : drawLink,
   'Cmd-Alt-I': drawImage,
   "Cmd-'"    : toggleBlockquote,
   'Cmd-Alt-L': toggleOrderedList,
   'Cmd-L'    : toggleUnOrderedList
};

/* Fix shortcut. Mac use Command, others use Ctrl */
function fixShortcut( name ) {
   if (isMac) name = name.replace( 'Ctrl', 'Cmd' );
   else name = name.replace( 'Cmd', 'Ctrl' );

   return name;
}

/* Create icon element for toolbar */
function createIcon( name, options ) {
   options = options || {};

   var el = document.createElement( 'a' );
   var shortcut = options.shortcut || shortcuts[ name ];

   if (shortcut) {
      el.title = fixShortcut( shortcut );
      el.title = el.title.replace( 'Cmd', '⌘' );

      if (isMac) el.title = el.title.replace( 'Alt', '⌥' );
   }

   el.className = options.className || 'icon-' + name;
   return el;
}

function createSep() {
   el = document.createElement( 'i' );
   el.className = 'separator';
   el.innerHTML = '|';
   return el;
}

/* The state of CodeMirror at the given position */
function getState( cm, pos ) {
   pos = pos || cm.getCursor( 'start' );

   var stat = cm.getTokenAt( pos ); if (!stat.type) return {};

   var types = stat.type.split( ' ' ), ret = {}, data, text;

   for (var i = 0, tl = types.length; i < tl; i++) {
      data = types[ i ];

      if      (data === 'strong') ret.bold = true;
      else if (data === 'variable-2') {
         text = cm.getLine( pos.line );

         if (/^\s*\d+\.\s/.test( text )) ret[ 'ordered-list' ] = true;
         else ret[ 'unordered-list' ] = true;
      }
      else if (data === 'atom') ret.quote = true;
      else if (data === 'em') ret.italic = true;
   }

   return ret;
}

/* Toggle full screen of the editor
 * https://developer.mozilla.org/en-US/docs/DOM/Using_fullscreen_mode */
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

/* Action for toggling bold */
function toggleBold(editor) {
   var cm         = editor.codemirror;
   var stat       = getState( cm );
   var startPoint = cm.getCursor( 'start' );
   var endPoint   = cm.getCursor( 'end' );
   var start      = '**';
   var end        = '**';
   var text;

   if (stat.bold) {
      text  = cm.getLine( startPoint.line );
      start = text.slice( 0, startPoint.ch );
      end   = text.slice( startPoint.ch );
      start = start.replace( /^(.*)?(\*|\_){2}(\S+.*)?$/, '$1$3' );
      end   = end.replace( /^(.*\S+)?(\*|\_){2}(\s+.*)?$/, '$1$3' );
      startPoint.ch -= 2;
      endPoint.ch   -= 2;
      cm.setLine( startPoint.line, start + end );
   }
   else {
      text = cm.getSelection();
      cm.replaceSelection( start + text + end );
      startPoint.ch += 2;
      endPoint.ch   += 2;
   }

   cm.setSelection( startPoint, endPoint );
   cm.focus();
}

/* Action for toggling italic */
function toggleItalic( editor ) {
   var cm         = editor.codemirror;
   var stat       = getState( cm );
   var startPoint = cm.getCursor( 'start' );
   var endPoint   = cm.getCursor( 'end' );
   var start      = '*';
   var end        = '*';
   var text;

   if (stat.italic) {
      text  = cm.getLine( startPoint.line );
      start = text.slice( 0, startPoint.ch );
      end   = text.slice( startPoint.ch );
      start = start.replace( /^(.*)?(\*|\_)(\S+.*)?$/, '$1$3' );
      end   = end.replace( /^(.*\S+)?(\*|\_)(\s+.*)?$/, '$1$3' );
      startPoint.ch -= 1;
      endPoint.ch   -= 1;
      cm.setLine( startPoint.line, start + end );
   }
   else {
      text = cm.getSelection();
      cm.replaceSelection( start + text + end );
      startPoint.ch += 1;
      endPoint.ch   += 1;
   }

   cm.setSelection( startPoint, endPoint );
   cm.focus();
}

/* Action for toggling blockquote */
function toggleBlockquote( editor ) {
   var cm = editor.codemirror; _toggleLine( cm, 'quote' );
}

/* Action for toggling ul */
function toggleUnOrderedList( editor ) {
   var cm = editor.codemirror; _toggleLine( cm, 'unordered-list' );
}

/* Action for toggling ol */
function toggleOrderedList( editor ) {
   var cm = editor.codemirror; _toggleLine( cm, 'ordered-list' );
}

/* Action for drawing a link */
function drawLink( editor ) {
   var cm = editor.codemirror, stat = getState( cm );

   _replaceSelection( cm, stat.link, '[', '](http://)' );
}

/* Action for drawing an img */
function drawImage( editor ) {
   var cm = editor.codemirror, stat = getState( cm );

   _replaceSelection( cm, stat.image, '![', '](http://)' );
}

function insertGraves( editor ) {
   var cm         = editor.codemirror;
   var startPoint = cm.getCursor( 'start' );
   var endPoint   = cm.getCursor( 'end' );
   var text       = cm.getSelection();
   var start      = '```';
   var end        = '```';

   cm.replaceSelection( start + text + end );
   startPoint.ch += 3;
   cm.setSelection( startPoint, endPoint );
   cm.focus();
}

/* Undo action */
function undo( editor ) {
   var cm = editor.codemirror; cm.undo(); cm.focus();
}

/* Redo action */
function redo( editor ) {
   var cm = editor.codemirror; cm.redo(); cm.focus();
}

/* Preview action */
function togglePreview( editor ) {
   var toolbar = editor.toolbar.preview;
   var parse   = editor.constructor.markdown;
   var cm      = editor.codemirror;
   var wrapper = cm.getWrapperElement();
   var preview = wrapper.lastChild;

   if (!/editor-preview/.test( preview.className )) {
      preview = document.createElement( 'div' );
      preview.className = 'editor-preview';
      wrapper.appendChild( preview );
   }

   if (/editor-preview-active/.test( preview.className )) {
      preview.className
         = preview.className.replace( /\s*editor-preview-active\s*/g, '' );
      toolbar.className = toolbar.className.replace( /\s*active\s*/g, '' );
   }
   else {
      /* When the preview button is clicked for the first time,
       * give some time for the transition from editor.css to fire and the
       * view to slide from right to left, instead of just appearing */
      setTimeout( function() {
         preview.className += ' editor-preview-active' }, 1 );
      toolbar.className += ' active';
   }

   var text = cm.getValue(); preview.innerHTML = parse( text );
}

function _replaceSelection( cm, active, start, end ) {
   var startPoint = cm.getCursor( 'start' ), endPoint = cm.getCursor( 'end' );
   var text;

   if (active) {
      text  = cm.getLine( startPoint.line );
      start = text.slice( 0, startPoint.ch );
      end   = text.slice( startPoint.ch );
      cm.setLine( startPoint.line, start + end );
   }
   else {
      text = cm.getSelection();
      cm.replaceSelection( start + text + end );
      startPoint.ch += start.length;
      endPoint.ch   += start.length;
   }

   cm.setSelection( startPoint, endPoint );
   cm.focus();
}

function _toggleLine( cm, name ) {
   var stat       = getState( cm );
   var startPoint = cm.getCursor( 'start' );
   var endPoint   = cm.getCursor( 'end' );
   var repl = {
      'quote'         : /^(\s*)\>\s+/,
      'unordered-list': /^(\s*)(\*|\-|\+)\s+/,
      'ordered-list'  : /^(\s*)\d+\.\s+/
   };
   var map = {
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

/* The right word count in respect for CJK. */
function wordCount( data ) {
   var pattern = /[a-zA-Z0-9_\u0392-\u03c9]+|[\u4E00-\u9FFF\u3400-\u4dbf\uf900-\ufaff\u3040-\u309f\uac00-\ud7af]+/g;
   var m = data.match( pattern ), count = 0;

   if (m === null) return count;

   for (var i = 0, ml = m.length; i < ml; i++) {
      if (m[ i ].charCodeAt( 0 ) >= 0x4E00) count += m[ i ].length;
      else count += 1;
   }

   return count;
}

/* Editor - editor.js */
var toolbar = [
   { name: 'bold', action: toggleBold },
   { name: 'italic', action: toggleItalic },
   '|',
   { name: 'quote', action: toggleBlockquote },
   { name: 'unordered-list', action: toggleUnOrderedList },
   { name: 'ordered-list', action: toggleOrderedList },
   '|',
   { name: 'link', action: drawLink },
   { name: 'image', action: drawImage },
   { name: 'codeblock', action: insertGraves },
   '|',
   { name: 'undo', action: undo },
   { name: 'redo', action: redo },
   { name: 'fullscreen', action: toggleFullScreen }
];

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
   // If user has passed an element, it should auto rendered
   if (this.element) this.render();
}

/* Default toolbar elements */
Editor.toolbar = toolbar;

/* Default markdown render */
Editor.markdown = function( text ) { // Use marked as markdown parser
   if (window.marked) return marked( text );
};

/* Render editor to the given element */
Editor.prototype.render = function( el ) {
   this.element = el || this.element
                     || document.getElementsByTagName( 'textarea' )[ 0 ];

   if (this._rendered && this._rendered === this.element) return;

   this.createCodeMirror( this.element );

   if (this.options.toolbar !== false) this.createToolbar();
   if (this.options.status  !== false) this.createStatusbar();

   this._rendered = this.element;
};

Editor.prototype.createCodeMirror = function( el ) {
   var self = this, keyMaps = {};

   for (var key in shortcuts) {
      (function( key ) {
         keyMaps[ fixShortcut( key ) ] = function( cm ) {
            shortcuts[ key ]( self );
         };
      })( key );
   }

   keyMaps[ 'Enter' ] = 'newlineAndIndentContinueMarkdownList';

   var codeMirrorOptions  = this.options.codeMirror || {};
   var codeMirrorDefaults = {
      extraKeys     : keyMaps,
      indentWithTabs: true,
      lineNumbers   : false,
      mode          : 'markdown',
      theme         : 'paper'
   };

   for (var key in codeMirrorDefaults) {
      codeMirrorOptions[ key ] = codeMirrorOptions[ key ]
                              || codeMirrorDefaults[ key ];
   }

   this.codemirror = CodeMirror.fromTextArea( el, codeMirrorOptions );
};

Editor.prototype.createToolbar = function( items ) {
   var self = this; items = items || this.options.toolbar;

   if (!items || items.length === 0) return;

   var bar  = document.createElement( 'div' ); bar.className = 'editor-toolbar';

   self.toolbar = {};

   for (var i = 0, il = items.length; i < il; i++) {
      (function( item ) {
         var el;

         if      (item.name)    el = createIcon( item.name, item );
         else if (item === '|') el = createSep();
         else                   el = createIcon( item );

         // bind events, special for info
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
      var stat = getState( cm );

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

/* Bind static methods for exports */
Editor.toggleBold = toggleBold;
Editor.toggleItalic = toggleItalic;
Editor.toggleBlockquote = toggleBlockquote;
Editor.toggleUnOrderedList = toggleUnOrderedList;
Editor.toggleOrderedList = toggleOrderedList;
Editor.drawLink = drawLink;
Editor.drawImage = drawImage;
Editor.insertGraves = insertGraves;
Editor.undo = undo;
Editor.redo = redo;
Editor.toggleFullScreen = toggleFullScreen;

/* Bind instance methods for exports */
Editor.prototype.toggleBold = function() {
   toggleBold( this );
};
Editor.prototype.toggleItalic = function() {
   toggleItalic( this );
};
Editor.prototype.toggleBlockquote = function() {
   toggleBlockquote( this );
};
Editor.prototype.toggleUnOrderedList = function() {
   toggleUnOrderedList( this );
};
Editor.prototype.toggleOrderedList = function() {
   toggleOrderedList( this );
};
Editor.prototype.drawLink = function() {
   drawLink( this );
};
Editor.prototype.drawImage = function() {
   drawImage( this );
};
Editor.prototype.insertGraves = function() {
   insertGraves( this );
};
Editor.prototype.undo = function() {
   undo( this );
};
Editor.prototype.redo = function() {
   redo( this );
};
Editor.prototype.toggleFullScreen = function() {
   toggleFullScreen( this );
};

window.Editor = Editor;

})( window );
