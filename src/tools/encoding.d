/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */
module encoding;

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

unittest {
  import utils : check;
  import std.regex : matchFirst, regex;
  import std.stdio : writefln;

  check(base64Encode("hello"),        "aGVsbG8=", "base64Encode: basic");
  check(base64Encode(""),             "",          "base64Encode: empty");
  check(base64Decode("aGVsbG8="),     "hello",     "base64Decode: basic");
  check(base64Decode(base64Encode("roundtrip")), "roundtrip", "base64: roundtrip");

  check(md5Hash(""),      "d41d8cd98f00b204e9800998ecf8427e", "md5Hash: empty");
  check(md5Hash("hello"), "5d41402abc4b2a76b9719d911017c592", "md5Hash: hello");

  check(sha256Hash(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "sha256Hash: empty");

  auto uuid = generateUUID();
  assert(uuid.length == 36, "generateUUID: length");
  assert(matchFirst(uuid, regex(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")), "generateUUID: format");
  writefln("  PASS: generateUUID: format and length");
}

