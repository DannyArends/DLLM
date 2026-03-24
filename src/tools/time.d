/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */
module time;

import std.conv : to;
import std.datetime;
import std.format : format;

import tools : Tool, RegisterTools;

mixin RegisterTools;

@Tool("The current date and time in ISO 8601 format (YYYY-MM-DD HH:MM:SS)")
string currentTime() {
  try {
    return Clock.currTime().toISOExtString();
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("The current Unix timestamp")
string currentTimestamp() {
  try {
    return to!string(Clock.currTime().toUnixTime());
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("The current date in YYYY-MM-DD format")
string currentDate() {
  try {
    return Clock.currTime().toISOExtString()[0..10];
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("The day of the week for a date (YYYY-MM-DD) (mon, tue, wed, etc.)")
string dayOfWeek(string date) {
  try {
    auto dt = Date.fromISOExtString(date);
    return to!string(dt.dayOfWeek);
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Add or subtract days from any date (YYYY-MM-DD). A positive number adds, A negative subtracts. Returns the date in YYYY-MM-DD format.")
string addDays(string date, string days) {
  try {
    int numDays = to!int(days);
    auto dt = Date.fromISOExtString(date);
    auto newDate = dt + dur!"days"(numDays);
    return newDate.toISOExtString()[0..10];
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Calculate the number of days between two dates (format: YYYY-MM-DD). Positive if date2 is after date1, negative otherwise.")
string daysBetween(string date1, string date2) {
  try {
    auto d1 = Date.fromISOExtString(date1);
    auto d2 = Date.fromISOExtString(date2);
    auto diff = d2 - d1;
    return to!string(diff.total!"days");
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Check if a date (YYYY-MM-DD) is in the 'Past' or 'Future'.")
string isDatePast(string date) {
  try {
    auto checkDate = Date.fromISOExtString(date);
    auto today = cast(Date)Clock.currTime();
    return checkDate < today ? "Past" : "Future";
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

unittest {
  import utils : check;
  check(dayOfWeek("2024-01-01"), "mon", "dayOfWeek: monday");
  check(dayOfWeek("2024-12-25"), "wed", "dayOfWeek: wednesday");
  check(dayOfWeek("2000-01-01"), "sat", "dayOfWeek: saturday");

  check(addDays("2024-01-01",  "1"),  "2024-01-02", "addDays: forward");
  check(addDays("2024-01-01",  "-1"), "2023-12-31", "addDays: backward across year");
  check(addDays("2024-02-28",  "1"),  "2024-02-29", "addDays: leap year");
  check(addDays("2024-02-29",  "1"),  "2024-03-01", "addDays: past leap day");

  check(daysBetween("2024-01-01", "2024-01-11"), "10",  "daysBetween: positive");
  check(daysBetween("2024-01-11", "2024-01-01"), "-10", "daysBetween: negative");
  check(daysBetween("2024-01-01", "2024-01-01"), "0",   "daysBetween: same day");

  check(isDatePast("2000-01-01"), "Past",   "isDatePast: past");
  check(isDatePast("2999-01-01"), "Future", "isDatePast: future");
}

