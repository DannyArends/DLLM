/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import std.array : appender;
import std.format : format;
import std.json : JSONValue, parseJSON;
import std.regex : regex, matchAll;
import std.string : lastIndexOf;
import std.stdio : writefln, writef, writeln, write;

// UDA for marking tool functions
struct Tool {
  string description;
}

// Tool parameter definition
struct ToolParam {
    string name;
    string type;
}

// Tool definition
struct ToolDef {
  string name;
  string description;
  ToolParam[] parameters;
  string function(JSONValue) executor;
}

// Tool Call definition
struct ToolCall {
  string name;
  JSONValue arguments;
}

// Tool registry
__gshared ToolDef[] ALL_TOOLS;

// Mixin template to auto-register all @Tool functions in a module
mixin template RegisterTools() {
  static this() {
    import tools : ALL_TOOLS, Tool, ToolDef, ToolParam;
    import std.conv : to;
    import std.traits : hasUDA, getUDAs, ParameterIdentifierTuple;
    import std.json : JSONValue;
    import std.array : join;

    // Get reference to current module an scan all functions for UDAs
    mixin("alias ThisModule = " ~ __MODULE__ ~ ";");

    static foreach(name; __traits(allMembers, ThisModule)) {{
      static if (name != "object" && name != "ThisModule") {
        mixin("alias member = " ~ name ~ ";");
        static if (is(typeof(member) == function)) {
          static if (hasUDA!(member, Tool)) {
            // Get the tool description, parameters, and executor
            enum description = getUDAs!(member, Tool)[0].description;
            alias ParamNames = ParameterIdentifierTuple!member;

            ToolParam[] parameters;
            static foreach(paramName; ParamNames) { parameters ~= ToolParam(paramName, "string"); }

            // Build the tool executor
            auto executor = (JSONValue args) {
              static foreach(paramName; ParamNames) {
                if (paramName !in args) { return "Error: missing " ~ paramName ~ " parameter"; }
              }

              string[] argValues;
              static foreach(paramName; ParamNames) { argValues ~= args[paramName].str; }

              enum callStr = {
                  string[] argRefs;
                  static foreach(i; 0 .. ParamNames.length) { argRefs ~= "argValues[" ~ i.to!string ~ "]"; }
                  return "return member(" ~ argRefs.join(", ") ~ ");";
              }();
              mixin(callStr);
            };
            ALL_TOOLS ~= ToolDef(name, description, parameters, executor);
          }
        }
      }
    }}
  }
}

string clean(string response){
  auto thinkEnd = response.lastIndexOf("</think>\n");
  if (thinkEnd >= 0) response = response[thinkEnd + "</think>\n".length .. $];
  return(response);
}

// Parse tool call from model output
ToolCall[] parseToolCalls(string response) {
  response = response.clean();

  ToolCall[] calls;
  auto pattern = regex(r"<tool_call>\s*(\{.*?\})\s*</tool_call>", "gs");
  foreach(match; matchAll(response, pattern)) {
    try {
      JSONValue json = parseJSON(match[1]);
      if ("name" in json && "arguments" in json) { calls ~= ToolCall(json["name"].str, json["arguments"]); }
    } catch (Exception e) {
      writefln("Failed to parse tool call: %s", e.msg);
    }
  }
  return(calls);
}

// Execute tool by name with JSON arguments
string executeTool(string toolName, JSONValue args) {
  try {
    foreach(tool; ALL_TOOLS) {
      if (tool.name == toolName) return(tool.executor(args));
    }
    return("Error: unknown tool '" ~ toolName ~ "'");
  } catch (Exception e) { return(format("Error executing tool: %s", e.msg)); }
}

// Execute all tool calls and format responses
string[] executeToolCalls(ToolCall[] calls) {
  string[] result;
  foreach(i, call; calls) {
    if (i > 0) result ~= "\n";
    string toolResult = executeTool(call.name, call.arguments);
    JSONValue response = JSONValue(["tool": JSONValue(call.name), "args": JSONValue(call.arguments), "result": JSONValue(toolResult)]);
    result ~= response.toString();
  }
  return(result);
}

// Generate tools JSON for system prompt
string toolsToJSON() {
  auto result = appender!string;

  result ~= "[";
  foreach(i, tool; ALL_TOOLS) {
    if (i > 0) result ~= ",";

    JSONValue properties = JSONValue.emptyObject;
    foreach(param; tool.parameters) { properties[param.name] = JSONValue(["type": JSONValue(param.type)]); }

    JSONValue toolJson = JSONValue([
      "name": JSONValue(tool.name),
      "description": JSONValue(tool.description),
      "parameters": JSONValue([
        "type": JSONValue("object"),
        "properties": properties
      ])
    ]);
    result ~= toolJson.toString();
  }
  result ~= "]";
  return(result.data);
}
