// Drag and drop handler for visual assets.
// Accepts image/* and video/* with a lightweight animated response.

export class DragDropHandler {
  constructor(dropZone, onFile, onInvalid) {
    this.dropZone = dropZone;
    this.onFile = onFile;
    this.onInvalid = onInvalid;
    this.dragCounter = 0;

    this._bind();
  }

  _bind() {
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach((eventName) => {
      document.addEventListener(eventName, (event) => event.preventDefault());
    });

    this.dropZone.addEventListener('dragenter', (event) => this._onDragEnter(event));
    this.dropZone.addEventListener('dragover', (event) => this._onDragOver(event));
    this.dropZone.addEventListener('dragleave', (event) => this._onDragLeave(event));
    this.dropZone.addEventListener('drop', (event) => this._onDrop(event));

    const fileInput = this.dropZone.querySelector('input[type="file"]');
    if (fileInput) {
      fileInput.addEventListener('change', (event) => {
        const [file] = event.target.files || [];
        if (!file) {
          return;
        }

        if (this._isSupported(file)) {
          this.onFile(file);
        } else if (this.onInvalid) {
          this.onInvalid(file);
        }

        event.target.value = '';
      });
    }
  }

  _isSupported(file) {
    return file.type.startsWith('video/') || file.type.startsWith('image/');
  }

  _onDragEnter(event) {
    event.preventDefault();
    this.dragCounter += 1;
    this.dropZone.classList.add('drag-over');
  }

  _onDragOver(event) {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'copy';
  }

  _onDragLeave(event) {
    event.preventDefault();
    this.dragCounter -= 1;

    if (this.dragCounter <= 0) {
      this.dragCounter = 0;
      this.dropZone.classList.remove('drag-over');
    }
  }

  _onDrop(event) {
    event.preventDefault();
    this.dragCounter = 0;
    this.dropZone.classList.remove('drag-over');
    this._spawnRipple(event);

    const files = Array.from(event.dataTransfer.files || []);
    const supported = files.find((file) => this._isSupported(file));

    if (supported) {
      this.onFile(supported);
      return;
    }

    if (files[0] && this.onInvalid) {
      this.onInvalid(files[0]);
    }
  }

  _spawnRipple(event) {
    const rect = this.dropZone.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;

    const ripple = document.createElement('div');
    ripple.className = 'drop-ripple';
    ripple.style.left = `${x - 56}px`;
    ripple.style.top = `${y - 56}px`;
    ripple.style.width = '112px';
    ripple.style.height = '112px';

    this.dropZone.appendChild(ripple);
    ripple.addEventListener('animationend', () => ripple.remove());
  }
}
