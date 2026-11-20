def main():
    var i = 0
    var s = 0
    while i < 1000000 and s >= 0:
        s += i
        i += 1
    print(s)
