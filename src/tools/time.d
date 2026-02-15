/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import std.conv : to;
import std.datetime;
import std.format : format;

import tools : Tool, RegisterTools;

mixin RegisterTools;

@Tool("Returns the current date and time in ISO 8601 format (YYYY-MM-DD HH:MM:SS)")
string currentTime() {
  try {
    return Clock.currTime().toISOExtString();
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Returns the current Unix timestamp (seconds since 1970-01-01)")
string currentTimestamp() {
  try {
    return to!string(Clock.currTime().toUnixTime());
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Returns the current date in YYYY-MM-DD format")
string currentDate() {
  try {
    return Clock.currTime().toISOExtString()[0..10];
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Returns the day of the week for today (Monday, Tuesday, etc.)")
string currentDayOfWeek() {
  try {
    auto now = Clock.currTime();
    return to!string(now.dayOfWeek);
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Returns the day of the week for any date (YYYY-MM-DD) (Monday, Tuesday, etc.)")
string dayOfWeek(string date) {
  try {
    auto dt = Date.fromISOExtString(date);
    return to!string(dt.dayOfWeek);
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Add or subtract days from any date (YYYY-MM-DD). Use positive number to add, negative to subtract. Returns date in YYYY-MM-DD format.")
string addDays(string date, string days) {
  try {
    int numDays = to!int(days);
    auto dt = Date.fromISOExtString(date);
    auto newDate = dt + dur!"days"(numDays);
    return newDate.toISOExtString()[0..10];
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Calculate the number of days between two dates (format: YYYY-MM-DD). Returns positive if date2 is after date1.")
string daysBetween(string date1, string date2) {
  try {
    auto d1 = Date.fromISOExtString(date1);
    auto d2 = Date.fromISOExtString(date2);
    auto diff = d2 - d1;
    return to!string(diff.total!"days");
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Check if a date (YYYY-MM-DD) is in the past. Returns 'true' or 'false'.")
string isDatePast(string date) {
  try {
    auto checkDate = Date.fromISOExtString(date);
    auto today = cast(Date)Clock.currTime();
    return checkDate < today ? "true" : "false";
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Format a Unix timestamp to human-readable date and time")
string formatTimestamp(string timestamp) {
  try {
    long ts = to!long(timestamp);
    auto dt = SysTime.fromUnixTime(ts);
    return dt.toISOExtString();
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}
