def samei(ref x: Int) -> ref [x] Int:
    return x


def main():
    var i = 7
    ref t = samei(i)
    var u = t^
    print(u + 1)
