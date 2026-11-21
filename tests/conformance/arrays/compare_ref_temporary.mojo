def pick(ref a: Array[Int, 2]) -> ref [a] Array[Int, 2]:
    return a


def main():
    var b = [1, 3]
    print(pick([1, 2]) < b, b == pick([1, 3]))
