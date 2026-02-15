/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import std.array : appender;
import std.conv : to;
import std.json : JSONValue, parseJSON;
import std.format : format;
import std.net.curl : get, HTTP;
import std.regex : regex, replaceAll;
import std.stdio : writefln;
import std.string : strip;
import std.uri : encodeComponent;

import files : writeFile;
import tools : Tool, RegisterTools;

mixin RegisterTools;

@Tool("Fetch URL content and save the content to temporary file. Returns a json with the path to the content and its length.")
string webFetch(string url) {
  try {
    //writefln("=== Fetching: %s", url);
    auto http = HTTP(url);
    http.addRequestHeader("User-Agent", "Lynx (textmode)");

    auto contentBuffer = appender!(ubyte[]);
    http.onReceive = (ubyte[] data) { contentBuffer ~= data; return data.length; };
    http.perform();
    string content = cast(string)contentBuffer.data;

    // Remove entire <head> section
    content = replaceAll(content, regex(r"<head[^>]*>.*?</head>", "gis"), "");

    // Remove scripts, styles, and comments
    content = replaceAll(content, regex(r"<script[^>]*>.*?</script>", "gis"), "");
    content = replaceAll(content, regex(r"<style[^>]*>.*?</style>", "gis"), "");
    content = replaceAll(content, regex(r"<!--.*?-->", "gs"), "");

    // Strip remaining HTML tags
    content = replaceAll(content, regex(r"<[^>]+>"), " ");

    // Collapse whitespace
    content = replaceAll(content, regex(r"\s+"), " ");
    content = content.strip();

    // Limit size
    const int MAX_SIZE = 50_000;
    if (content.length > MAX_SIZE) {
      content = content[0..MAX_SIZE];
      //writefln("=== Content truncated to %d chars", MAX_SIZE);
    }

    //writefln("=== Extracted %d chars", content.length);
    return writeFile(content);
  } catch (Exception e) { return "Error: " ~ e.msg; }
}

@Tool("Search the web using a query")
string webSearch(string query, string max_results) {
  try {
    int maxResults = to!int(max_results);
    string url = "http://localhost:8080/search?q=" ~ encodeComponent(query) ~ "&format=json";
    
    // Fetch search results (already limited by API)
    auto response = get(url);
    auto json = parseJSON(cast(string)response);
    JSONValue[] results;

    if ("results" in json) {
      foreach(i, item; json["results"].array) {
        if (i >= maxResults) break;
        JSONValue result = JSONValue.emptyObject;
        result["title"] = "title" in item ? item["title"] : JSONValue("No title");
        result["url"] = "url" in item ? item["url"] : JSONValue("");
        result["content"] = "content" in item ? item["content"] : JSONValue("");
        result["category"] = "category" in item ? item["category"] : JSONValue("");
        result["score"] = "score" in item ? item["score"] : JSONValue(0);
        results ~= result;
      }
    }

    return results.length > 0 ? JSONValue(results).toString() : "No results found";
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}
