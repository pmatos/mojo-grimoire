def main():
    print([True] == [True], [True] < [False], [False] < [True], [True, False] != [True, True])
    print([[1]] == [[1]], [[1]] < [[2]], [[1, 2], [3, 4]] < [[1, 2], [3, 5]])
    print([[True], [False]] >= [[True], [True]], [[[1]]] != [[[1]]])
