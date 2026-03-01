/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import std.base64 : Base64;
import std.digest : toHexString;
import std.digest.md : md5Of;
import std.digest.sha : sha256Of;
import std.uuid : randomUUID;
import std.conv : to;
import std.format : format;
import std.string : representation, toLower;

import tools : Tool, RegisterTools;

mixin RegisterTools;

@Tool("Encode text as Base64")
string base64Encode(string text) {
  try {
    return Base64.encode(cast(ubyte[])text);
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Decode Base64 to text")
string base64Decode(string encoded) {
  try {
    return cast(string)Base64.decode(encoded);
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Calculate the MD5 hash of text, returns a lowercase hexadecimal string.")
string md5Hash(string text) {
  try {
    return toHexString(md5Of(text.representation)).to!string.toLower();
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Calculate the SHA256 hash of text, Returns lowercase hexadecimal string.")
string sha256Hash(string text) {
  try {
    return toHexString(sha256Of(text.representation)).to!string.toLower();
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Generate a random UUID (Universally Unique IDentifier)")
string generateUUID() {
  try {
    return randomUUID().toString();
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}
