def at(ref a: Array[Int, 2]) -> ref [a] Int:
    return a[0]


def setf(mut b: Array[Int, 2]) -> Int:
    b[0] = 100
    return 0


def two(x: Int, y: Int) -> Int:
    return x + y


def twov(var x: Int, y: Int) -> Int:
    return x + y


def main():
    var a: Array[Int, 2] = [1, 2]
    print(two(at(a), setf(a)))
    a[0] = 1
    print(twov(at(a), setf(a)))
    a[0] = 1
    print(two(a[0], setf(a)))
