use str

fn read-stdin {
  from-lines | each {|p|
    var trimmed = (str:trim-space $p)
      if (not-eq $trimmed "") {
        put $trimmed
      }
  }
}
