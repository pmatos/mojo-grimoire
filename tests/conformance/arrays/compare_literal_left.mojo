def main():
    var a = [1]
    print([[1]] == a)
    var c = [1, 2]
    print([[1], [2]] != c, [[1], 2] == c, [1, [2]] == c, [[1], [2]] < c, [[0], 9] <= c)
    var x = 1
    print([[x], [2]] == c, x)
