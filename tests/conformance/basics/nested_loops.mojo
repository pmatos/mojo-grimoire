def main():
    var i = 0
    var count = 0
    while i < 4:
        var j = 0
        while j < i:
            count += 1
            j += 1
        i += 1
    print(count)
