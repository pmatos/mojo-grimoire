def samei(ref x: Int) -> ref [x] Int:
    return x


def main():
    var i = 7
    ref t = i
    var u = t^
    print(u)
    ref r = samei(i)
    var v = r^
    print(v + 1)
