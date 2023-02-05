# Architecture (WIP)

### Pipeline:
- pipelines follow the AWK model (BEGIN,PATTERN,END)
- pipelines have 3 types of Handlers: Begin, Stream, End
- pipelines (Begin) can only run once, unless calling reset
- pipelines (Stream to End) can run multiple times
- **todo:** pipelines keep a log/record in debug mode
- reset: `context.files.clear` and `context.state.clear`

### Begin:
- runs once
- defines files to process
- defines (shell) processes in background
- defines state in `context.state[namespace] = Class.new`
- defines files in `context.files[file_path] = FileContext.new`

### Stream:
- runs multiple times
- works on each individual file defined by Begin Handlers
- can modify files multiple times (across sequential Stream Handlers)

### End:
- runs after all Stream Handlers (runs once per compile)
- gets all finalized files from Stream Handlers
- creates,copies,deletes,etc. files for whatever use required

### Context
- files : Hash(String, FileContext)
  - key: string path of file
  - value: file context that tracks file through Stream handlers
- state : Hash(String, State)
  - key: namespace of custom state
  - value: custom state to be used throughout all handlers

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
