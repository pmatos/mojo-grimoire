def main():
    var v: Array[List[Int], 1] = [[1]]
    ref r = v[0][0]
    print(v[0])
    r = 5
    print(v[0])
