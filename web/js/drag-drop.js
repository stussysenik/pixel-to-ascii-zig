// Drag & Drop handler for video files
// Provides visual feedback and file extraction

export class DragDropHandler {
  constructor(dropZone, onFile) {
    this.dropZone = dropZone;
    this.onFile = onFile;
    this.dragCounter = 0;

    this._bind();
  }

  _bind() {
    const zone = this.dropZone;

    // Prevent default drag behaviors on document
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(event => {
      document.addEventListener(event, e => e.preventDefault());
    });

    // Drop zone specific handlers
    zone.addEventListener('dragenter', (e) => this._onDragEnter(e));
    zone.addEventListener('dragover', (e) => this._onDragOver(e));
    zone.addEventListener('dragleave', (e) => this._onDragLeave(e));
    zone.addEventListener('drop', (e) => this._onDrop(e));

    // File input fallback
    const fileInput = zone.querySelector('input[type="file"]');
    if (fileInput) {
      fileInput.addEventListener('change', (e) => {
        const file = e.target.files[0];
        if (file && file.type.startsWith('video/')) {
          this.onFile(file);
        }
      });
    }
  }

  _onDragEnter(e) {
    e.preventDefault();
    this.dragCounter++;
    this.dropZone.classList.add('drag-over');
  }

  _onDragOver(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'copy';
  }

  _onDragLeave(e) {
    e.preventDefault();
    this.dragCounter--;
    if (this.dragCounter <= 0) {
      this.dragCounter = 0;
      this.dropZone.classList.remove('drag-over');
    }
  }

  _onDrop(e) {
    e.preventDefault();
    this.dragCounter = 0;
    this.dropZone.classList.remove('drag-over');

    // Create ripple effect at drop position
    this._spawnRipple(e);

    // Extract video file
    const files = e.dataTransfer.files;
    for (const file of files) {
      if (file.type.startsWith('video/')) {
        this.onFile(file);
        return;
      }
    }
  }

  _spawnRipple(e) {
    const rect = this.dropZone.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    const ripple = document.createElement('div');
    ripple.className = 'drop-ripple';
    ripple.style.left = `${x - 50}px`;
    ripple.style.top = `${y - 50}px`;
    ripple.style.width = '100px';
    ripple.style.height = '100px';

    this.dropZone.appendChild(ripple);
    ripple.addEventListener('animationend', () => ripple.remove());
  }
}
