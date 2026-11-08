# Splits one command line, as typed, into words and operators, one to a line: "W<word>" or "O<operator>".
# Quotes are taken off as the shell would; nothing is expanded or run. Comments are dropped, a here-document's text is
# skipped, and $( ), backticks and brackets end a command, as a separator would. Plain POSIX awk, for macOS and Linux.
BEGIN { RS = "\001" }
{
  s = $0; n = length(s); w = ""; inw = 0; q = ""; hd = ""; want = 0; i = 1
  while (i <= n) {
    c = substr(s, i, 1); d = substr(s, i + 1, 1)
    if (q == "'") { if (c == "'") q = ""; else w = w c; i++; continue }
    if (q == "\"") {
      if (c == "\\" && i < n) { w = w d; i += 2; continue }
      if (c == "\"") q = ""; else w = w c
      i++; continue
    }
    if (c == "'" || c == "\"") { q = c; inw = 1; i++; continue }
    if (c == "\\" && i < n) { if (d != "\n") w = w d; inw = 1; i += 2; continue }
    if (c == " " || c == "\t") { flush(); i++; continue }
    if (c == "\n") {
      flush(); print "O;"; i++
      if (hd != "") { i = skipdoc(i); hd = "" }
      continue
    }
    if (c == "#" && !inw) { while (i <= n && substr(s, i, 1) != "\n") i++; continue }
    if (c == "|") { flush(); if (d == "|") { print "O||"; i += 2 } else { print "O|"; i++ } continue }
    if (c == "&") {
      flush()
      if (d == "&") { print "O&&"; i += 2 } else if (d == ">") { print "O>"; i += 2 } else { print "O&"; i++ }
      continue
    }
    if (c == ";") { flush(); print "O;"; i++; continue }
    if (c == ">") {
      if (inw && w ~ /^[0-9]+$/) { w = ""; inw = 0 }
      flush()
      if (d == ">") { print "O>>"; i += 2 } else { print "O>"; i++ }
      if (substr(s, i, 1) == "&") i++
      continue
    }
    if (c == "<") {
      flush()
      if (d == "<" && substr(s, i + 2, 1) == "<") { print "O<<<"; i += 3; continue }
      if (d == "<") { print "O<<"; i += 2; if (substr(s, i, 1) == "-") i++; want = 1; continue }
      print "O<"; i++; continue
    }
    if (c == "$" && d == "(") { flush(); print "O;"; i += 2; continue }
    if (c == "(" || c == ")" || c == "`") { flush(); print "O;"; i++; continue }
    w = w c; inw = 1; i++
  }
  flush()
}

function flush() {
  if (inw) {
    gsub(/\n/, " ", w)
    print "W" w
    if (want) { hd = w; want = 0 }
  }
  w = ""; inw = 0
}

# Skips a here-document's lines, from position p, up to and including the line that ends it.
function skipdoc(p,    line, e) {
  while (p <= n) {
    e = index(substr(s, p), "\n")
    if (e == 0) { line = substr(s, p); p = n + 1 } else { line = substr(s, p, e - 1); p = p + e }
    sub(/^\t+/, "", line)
    if (line == hd) return p
  }
  return p
}
