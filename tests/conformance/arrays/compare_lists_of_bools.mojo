def main():
    var x: List[Bool] = [True]
    var a = [x.copy(), x.copy()]
    var b = [x.copy(), List[Bool]()]
    print(a == b, a != b)
