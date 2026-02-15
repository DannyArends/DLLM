## Tools

D language tool implementations for the LLM agent system. Tools are automatically registered and exposed to the agent via JSON schema.

### Architecture

- Each tool is annotated with `@Tool(description)` 
- `mixin RegisterTools` auto-registers functions
- All tools return `string` (plain text or JSON)
- Error handling via try-catch, returns `"Error: <msg>"`
- Tool calls parsed from agent output, executed, and results fed back

### Available Tools

#### Counting (`counting.d`)
- **countWords** - Count words in text
- **nOccurrences** - Count substring occurrences  
- **wordLength** - Get character count

#### Encoding (`encoding.d`)
- **base64Encode/Decode** - Base64 encoding/decoding
- **md5Hash** - MD5 hash (lowercase hex)
- **sha256Hash** - SHA256 hash (lowercase hex)
- **generateUUID** - Random UUID v4

#### Files (`files.d`)
- **readFile** - Read file contents
- **fileExists** - Check existence (returns "true"/"false")
- **fileSize** - Get size in bytes
- **listDirectory** - List entries (returns JSON array)
- **writeFile** - Write to temp file (returns JSON with path/length)

#### Time (`time.d`)
- **currentTime** - Current datetime (ISO 8601)
- **currentTimestamp** - Unix timestamp
- **currentDate** - Date (YYYY-MM-DD)
- **currentDayOfWeek** - Day name
- **addDays** - Add/subtract days from now
- **daysBetween** - Days between two dates
- **isDatePast** - Check if date is past (returns "true"/"false")
- **formatTimestamp** - Format Unix timestamp to ISO 8601

#### Web (`web.d`)
- **webFetch** - Fetch URL, strip HTML, save to temp file (returns JSON with path/length)
- **webSearch** - Search via SearXNG at localhost:8080 (returns JSON array, max_results parameter)

### Adding New Tools

1. Create new `.d` file in tools folder
2. Import `tools : Tool, RegisterTools`
3. Add `mixin RegisterTools;`
4. Define functions with `@Tool("description")` annotation
5. Return `string` (use `format()` for JSON)
6. Wrap in try-catch, return error messages as strings

Example:
```d
import tools : Tool, RegisterTools;
mixin RegisterTools;

@Tool("Adds two numbers")
string add(string a, string b) {
  try {
    return to!string(to!int(a) + to!int(b));
  } catch (Exception e) { 
    return format("Error: %s", e.msg); 
  }
}
```

### Usage

Tools are automatically discovered and registered. The agent receives tool schemas via `toolsToJSON()`, makes 
tool calls in its output, which are parsed by `parseToolCalls()` and executed via `executeToolCalls()`.
