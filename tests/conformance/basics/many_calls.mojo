def inc(k: Int) -> Int:
    return k + 1


def main():
    var i = 0
    var s = 0
    while i < 400000:
        s = inc(s)
        i += 1
    print(s)
