def main():
    print([List[Int]()] == [List[Int]()])
    var x: List[Int] = [1]
    var y: List[Int] = [2]
    var a = [List[Int](), x.copy()]
    var b = [List[Int](), y.copy()]
    print(a == b, a != b, a == a)
