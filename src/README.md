# Architecture (WIP)

### Pipeline:
- pipelines follow the AWK model (BEGIN,PATTERN,END)
- pipelines have 3 types of Handlers: Initializers, Streams, Destroyers
- Initializers can only run once, unless calling reset
- Streams and Destroyers can run multiple times
- **todo:** pipelines keep a log/record in debug mode
- reset: clears both files and cache

### Initializer:
- runs once
- defines files to process
- defines (shell) processes in background
- defines (optional) cache

### Stream:
- runs multiple times
- works on each individual file defined by Initializers
- can modify files multiple times (through sequential Stream Handlers)

### Destroyer:
- runs after all Stream Handlers (runs once per compile)
- gets all finalized files from Stream Handlers
- creates,copies,deletes,etc. files for whatever use required

### Context
- files : Hash(String, FileState)
  - key: string path of file
  - value: file state that tracks file through Stream handlers
- cache : Hash(String, String)
  - key: namespace of custom cache
  - value: custom cache to be used throughout all handlers

### Sprockets examples

#### Sprockets Input
- :data (context.files[].file_contents) - The string contents of the asset
- :environment (context) - The current Sprockets::Environment instance
- :cache (?) - The Sprockets::Cache instance
- :uri (context.files[].file_uri) - The asset URI
- :source_path (context.files[].file_path) - The full path to original file
- :load_path (X) - The current load path for the file
- :name (context.files[]) - The logical name of the file
- :content_type (context.files[].file_mime_type) - The MIME type of the output asset
- :metadata (context.state) - The Hash of processor metadata

#### Sprockets Output
- :data (context.files[].file_contents) - Replaces the assets `input[:data]` for the next processor in the chain
- :required (X) - A Set of String asset URIs that Bundle processor should concatenate together
- :stubbed (X) - A Set of String asset URIs that will be omitted from the :required set
- :links (X) - A Set of String asset URIs that should be compiled along with the assets
- :dependencies (X) - A Set of String cache URIs that should be monitored for caching
- :map (?) - An Array of source maps for the assets
- :charset (context.files[].file_mime_type) - The MIME charset for an asset
