///|
fn read_white_code(input : @pdfio.Bitstream) -> Int raise {
  let a = input.getbitint()
  let b = input.getbitint()
  let c = input.getbitint()
  let d = input.getbitint()
  match (a, b, c, d) {
    (0, 1, 1, 1) => 2
    (1, 0, 0, 0) => 3
    (1, 0, 1, 1) => 4
    (1, 1, 0, 0) => 5
    (1, 1, 1, 0) => 6
    (1, 1, 1, 1) => 7
    _ => {
      let e = input.getbitint()
      match (a, b, c, d, e) {
        (1, 0, 0, 1, 1) => 8
        (1, 0, 1, 0, 0) => 9
        (0, 0, 1, 1, 1) => 10
        (0, 1, 0, 0, 0) => 11
        (1, 1, 0, 1, 1) => 64 + read_white_code(input)
        (1, 0, 0, 1, 0) => 128 + read_white_code(input)
        _ => {
          let f = input.getbitint()
          match (a, b, c, d, e, f) {
            (0, 0, 0, 1, 1, 1) => 1
            (0, 0, 1, 0, 0, 0) => 12
            (0, 0, 0, 0, 1, 1) => 13
            (1, 1, 0, 1, 0, 0) => 14
            (1, 1, 0, 1, 0, 1) => 15
            (1, 0, 1, 0, 1, 0) => 16
            (1, 0, 1, 0, 1, 1) => 17
            (0, 1, 0, 1, 1, 1) => 192 + read_white_code(input)
            (0, 1, 1, 0, 0, 0) => 1664 + read_white_code(input)
            _ => {
              let g = input.getbitint()
              match (a, b, c, d, e, f, g) {
                (0, 1, 0, 0, 1, 1, 1) => 18
                (0, 0, 0, 1, 1, 0, 0) => 19
                (0, 0, 0, 1, 0, 0, 0) => 20
                (0, 0, 1, 0, 1, 1, 1) => 21
                (0, 0, 0, 0, 0, 1, 1) => 22
                (0, 0, 0, 0, 1, 0, 0) => 23
                (0, 1, 0, 1, 0, 0, 0) => 24
                (0, 1, 0, 1, 0, 1, 1) => 25
                (0, 0, 1, 0, 0, 1, 1) => 26
                (0, 1, 0, 0, 1, 0, 0) => 27
                (0, 0, 1, 1, 0, 0, 0) => 28
                (0, 1, 1, 0, 1, 1, 1) => 256 + read_white_code(input)
                _ => {
                  let h = input.getbitint()
                  match (a, b, c, d, e, f, g, h) {
                    (0, 0, 1, 1, 0, 1, 0, 1) => 0
                    (0, 0, 0, 0, 0, 0, 1, 0) => 29
                    (0, 0, 0, 0, 0, 0, 1, 1) => 30
                    (0, 0, 0, 1, 1, 0, 1, 0) => 31
                    (0, 0, 0, 1, 1, 0, 1, 1) => 32
                    (0, 0, 0, 1, 0, 0, 1, 0) => 33
                    (0, 0, 0, 1, 0, 0, 1, 1) => 34
                    (0, 0, 0, 1, 0, 1, 0, 0) => 35
                    (0, 0, 0, 1, 0, 1, 0, 1) => 36
                    (0, 0, 0, 1, 0, 1, 1, 0) => 37
                    (0, 0, 0, 1, 0, 1, 1, 1) => 38
                    (0, 0, 1, 0, 1, 0, 0, 0) => 39
                    (0, 0, 1, 0, 1, 0, 0, 1) => 40
                    (0, 0, 1, 0, 1, 0, 1, 0) => 41
                    (0, 0, 1, 0, 1, 0, 1, 1) => 42
                    (0, 0, 1, 0, 1, 1, 0, 0) => 43
                    (0, 0, 1, 0, 1, 1, 0, 1) => 44
                    (0, 0, 0, 0, 0, 1, 0, 0) => 45
                    (0, 0, 0, 0, 0, 1, 0, 1) => 46
                    (0, 0, 0, 0, 1, 0, 1, 0) => 47
                    (0, 0, 0, 0, 1, 0, 1, 1) => 48
                    (0, 1, 0, 1, 0, 0, 1, 0) => 49
                    (0, 1, 0, 1, 0, 0, 1, 1) => 50
                    (0, 1, 0, 1, 0, 1, 0, 0) => 51
                    (0, 1, 0, 1, 0, 1, 0, 1) => 52
                    (0, 0, 1, 0, 0, 1, 0, 0) => 53
                    (0, 0, 1, 0, 0, 1, 0, 1) => 54
                    (0, 1, 0, 1, 1, 0, 0, 0) => 55
                    (0, 1, 0, 1, 1, 0, 0, 1) => 56
                    (0, 1, 0, 1, 1, 0, 1, 0) => 57
                    (0, 1, 0, 1, 1, 0, 1, 1) => 58
                    (0, 1, 0, 0, 1, 0, 1, 0) => 59
                    (0, 1, 0, 0, 1, 0, 1, 1) => 60
                    (0, 0, 1, 1, 0, 0, 1, 0) => 61
                    (0, 0, 1, 1, 0, 0, 1, 1) => 62
                    (0, 0, 1, 1, 0, 1, 0, 0) => 63
                    (0, 0, 1, 1, 0, 1, 1, 0) => 320 + read_white_code(input)
                    (0, 0, 1, 1, 0, 1, 1, 1) => 384 + read_white_code(input)
                    (0, 1, 1, 0, 0, 1, 0, 0) => 448 + read_white_code(input)
                    (0, 1, 1, 0, 0, 1, 0, 1) => 512 + read_white_code(input)
                    (0, 1, 1, 0, 1, 0, 0, 0) => 576 + read_white_code(input)
                    (0, 1, 1, 0, 0, 1, 1, 1) => 640 + read_white_code(input)
                    _ => {
                      let j = input.getbitint()
                      match (a, b, c, d, e, f, g, h, j) {
                        (0, 1, 1, 0, 0, 1, 1, 0, 0) =>
                          704 + read_white_code(input)
                        (0, 1, 1, 0, 0, 1, 1, 0, 1) =>
                          768 + read_white_code(input)
                        (0, 1, 1, 0, 1, 0, 0, 1, 0) =>
                          832 + read_white_code(input)
                        (0, 1, 1, 0, 1, 0, 0, 1, 1) =>
                          896 + read_white_code(input)
                        (0, 1, 1, 0, 1, 0, 1, 0, 0) =>
                          960 + read_white_code(input)
                        (0, 1, 1, 0, 1, 0, 1, 0, 1) =>
                          1024 + read_white_code(input)
                        (0, 1, 1, 0, 1, 0, 1, 1, 0) =>
                          1088 + read_white_code(input)
                        (0, 1, 1, 0, 1, 0, 1, 1, 1) =>
                          1152 + read_white_code(input)
                        (0, 1, 1, 0, 1, 1, 0, 0, 0) =>
                          1216 + read_white_code(input)
                        (0, 1, 1, 0, 1, 1, 0, 0, 1) =>
                          1280 + read_white_code(input)
                        (0, 1, 1, 0, 1, 1, 0, 1, 0) =>
                          1344 + read_white_code(input)
                        (0, 1, 1, 0, 1, 1, 0, 1, 1) =>
                          1408 + read_white_code(input)
                        (0, 1, 0, 0, 1, 1, 0, 0, 0) =>
                          1472 + read_white_code(input)
                        (0, 1, 0, 0, 1, 1, 0, 0, 1) =>
                          1536 + read_white_code(input)
                        (0, 1, 0, 0, 1, 1, 0, 1, 0) =>
                          1600 + read_white_code(input)
                        (0, 1, 0, 0, 1, 1, 0, 1, 1) =>
                          1728 + read_white_code(input)
                        _ => {
                          let k = input.getbitint()
                          let l = input.getbitint()
                          match (a, b, c, d, e, f, g, h, j, k, l) {
                            (0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0) =>
                              1792 + read_white_code(input)
                            (0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0) =>
                              1856 + read_white_code(input)
                            (0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1) =>
                              1920 + read_white_code(input)
                            _ => {
                              let m = input.getbitint()
                              match (a, b, c, d, e, f, g, h, j, k, l, m) {
                                (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1) => -1
                                (0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0) =>
                                  1984 + read_white_code(input)
                                (0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1) =>
                                  2048 + read_white_code(input)
                                (0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0) =>
                                  2112 + read_white_code(input)
                                (0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1) =>
                                  2176 + read_white_code(input)
                                (0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0) =>
                                  2240 + read_white_code(input)
                                (0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1) =>
                                  2304 + read_white_code(input)
                                (0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0) =>
                                  2368 + read_white_code(input)
                                (0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1) =>
                                  2432 + read_white_code(input)
                                (0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0) =>
                                  2496 + read_white_code(input)
                                (0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1) =>
                                  2560 + read_white_code(input)
                                _ => raise Failure::Failure("bad white code")
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

///|
fn read_black_code(input : @pdfio.Bitstream) -> Int raise {
  let a = input.getbitint()
  let b = input.getbitint()
  match (a, b) {
    (1, 1) => 2
    (1, 0) => 3
    _ => {
      let c = input.getbitint()
      match (a, b, c) {
        (0, 1, 0) => 1
        (0, 1, 1) => 4
        _ => {
          let d = input.getbitint()
          match (a, b, c, d) {
            (0, 0, 1, 1) => 5
            (0, 0, 1, 0) => 6
            _ => {
              let e = input.getbitint()
              match (a, b, c, d, e) {
                (0, 0, 0, 1, 1) => 7
                _ => {
                  let f = input.getbitint()
                  match (a, b, c, d, e, f) {
                    (0, 0, 0, 1, 0, 1) => 8
                    (0, 0, 0, 1, 0, 0) => 9
                    _ => {
                      let g = input.getbitint()
                      match (a, b, c, d, e, f, g) {
                        (0, 0, 0, 0, 1, 0, 0) => 10
                        (0, 0, 0, 0, 1, 0, 1) => 11
                        (0, 0, 0, 0, 1, 1, 1) => 12
                        _ => {
                          let h = input.getbitint()
                          match (a, b, c, d, e, f, g, h) {
                            (0, 0, 0, 0, 0, 1, 0, 0) => 13
                            (0, 0, 0, 0, 0, 1, 1, 1) => 14
                            _ => {
                              let j = input.getbitint()
                              match (a, b, c, d, e, f, g, h, j) {
                                (0, 0, 0, 0, 1, 1, 0, 0, 0) => 15
                                _ => {
                                  let k = input.getbitint()
                                  match (a, b, c, d, e, f, g, h, j, k) {
                                    (0, 0, 0, 0, 1, 1, 0, 1, 1, 1) => 0
                                    (0, 0, 0, 0, 0, 1, 0, 1, 1, 1) => 16
                                    (0, 0, 0, 0, 0, 1, 1, 0, 0, 0) => 17
                                    (0, 0, 0, 0, 0, 0, 1, 0, 0, 0) => 18
                                    (0, 0, 0, 0, 0, 0, 1, 1, 1, 1) =>
                                      64 + read_black_code(input)
                                    _ => {
                                      let l = input.getbitint()
                                      match (a, b, c, d, e, f, g, h, j, k, l) {
                                        (0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1) => 19
                                        (0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0) => 20
                                        (0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0) => 21
                                        (0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1) => 22
                                        (0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0) => 23
                                        (0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1) => 24
                                        (0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0) => 25
                                        (0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0) =>
                                          1792 + read_black_code(input)
                                        (0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0) =>
                                          1856 + read_black_code(input)
                                        (0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1) =>
                                          1920 + read_black_code(input)
                                        _ => {
                                          let m = input.getbitint()
                                          match
                                            (a, b, c, d, e, f, g, h, j, k, l, m) {
                                            (0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 0) =>
                                              26
                                            (0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1) =>
                                              27
                                            (0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0) =>
                                              28
                                            (0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1) =>
                                              29
                                            (0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0) =>
                                              30
                                            (0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1) =>
                                              31
                                            (0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0) =>
                                              32
                                            (0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1) =>
                                              33
                                            (0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 0) =>
                                              34
                                            (0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1) =>
                                              35
                                            (0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0, 0) =>
                                              36
                                            (0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1) =>
                                              37
                                            (0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0) =>
                                              38
                                            (0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1) =>
                                              39
                                            (0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0) =>
                                              40
                                            (0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1) =>
                                              41
                                            (0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1, 0) =>
                                              42
                                            (0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1, 1) =>
                                              43
                                            (0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0) =>
                                              44
                                            (0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1) =>
                                              45
                                            (0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0) =>
                                              46
                                            (0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 1) =>
                                              47
                                            (0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0) =>
                                              48
                                            (0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1) =>
                                              49
                                            (0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0) =>
                                              50
                                            (0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1) =>
                                              51
                                            (0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0) =>
                                              52
                                            (0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1) =>
                                              53
                                            (0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0) =>
                                              54
                                            (0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1) =>
                                              55
                                            (0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0) =>
                                              56
                                            (0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0) =>
                                              57
                                            (0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1) =>
                                              58
                                            (0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1) =>
                                              59
                                            (0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0) =>
                                              60
                                            (0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0) =>
                                              61
                                            (0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0) =>
                                              62
                                            (0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1) =>
                                              63
                                            (0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0) =>
                                              128 + read_black_code(input)
                                            (0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 1) =>
                                              192 + read_black_code(input)
                                            (0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1) =>
                                              256 + read_black_code(input)
                                            (0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1) =>
                                              320 + read_black_code(input)
                                            (0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0) =>
                                              384 + read_black_code(input)
                                            (0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1) =>
                                              448 + read_black_code(input)
                                            (0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0) =>
                                              1984 + read_black_code(input)
                                            (0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1) =>
                                              2048 + read_black_code(input)
                                            (0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0) =>
                                              2112 + read_black_code(input)
                                            (0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1) =>
                                              2176 + read_black_code(input)
                                            (0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0) =>
                                              2240 + read_black_code(input)
                                            (0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1) =>
                                              2304 + read_black_code(input)
                                            (0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0) =>
                                              2368 + read_black_code(input)
                                            (0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1) =>
                                              2432 + read_black_code(input)
                                            (0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0) =>
                                              2496 + read_black_code(input)
                                            (0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1) =>
                                              2560 + read_black_code(input)
                                            (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1) =>
                                              -1
                                            _ => {
                                              let n = input.getbitint()
                                              match
                                                (
                                                  a, b, c, d, e, f, g, h, j, k, l,
                                                  m, n,
                                                ) {
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  1,
                                                  0,
                                                  1,
                                                  1,
                                                  0,
                                                  0,
                                                ) =>
                                                  512 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  1,
                                                  0,
                                                  1,
                                                  1,
                                                  0,
                                                  1,
                                                ) =>
                                                  576 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  0,
                                                  0,
                                                  1,
                                                  0,
                                                  1,
                                                  0,
                                                ) =>
                                                  640 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  0,
                                                  0,
                                                  1,
                                                  0,
                                                  1,
                                                  1,
                                                ) =>
                                                  704 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  0,
                                                  0,
                                                  1,
                                                  1,
                                                  0,
                                                  0,
                                                ) =>
                                                  768 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  0,
                                                  0,
                                                  1,
                                                  1,
                                                  0,
                                                  1,
                                                ) =>
                                                  832 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  1,
                                                  1,
                                                  0,
                                                  0,
                                                  1,
                                                  0,
                                                ) =>
                                                  896 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  1,
                                                  1,
                                                  0,
                                                  0,
                                                  1,
                                                  1,
                                                ) =>
                                                  960 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  1,
                                                  1,
                                                  0,
                                                  1,
                                                  0,
                                                  0,
                                                ) =>
                                                  1024 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  1,
                                                  1,
                                                  0,
                                                  1,
                                                  0,
                                                  1,
                                                ) =>
                                                  1088 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  1,
                                                  1,
                                                  0,
                                                  1,
                                                  1,
                                                  0,
                                                ) =>
                                                  1152 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  1,
                                                  1,
                                                  0,
                                                  1,
                                                  1,
                                                  1,
                                                ) =>
                                                  1216 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  0,
                                                  1,
                                                  0,
                                                  0,
                                                  1,
                                                  0,
                                                ) =>
                                                  1280 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  0,
                                                  1,
                                                  0,
                                                  0,
                                                  1,
                                                  1,
                                                ) =>
                                                  1344 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  0,
                                                  1,
                                                  0,
                                                  1,
                                                  0,
                                                  0,
                                                ) =>
                                                  1408 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  0,
                                                  1,
                                                  0,
                                                  1,
                                                  0,
                                                  1,
                                                ) =>
                                                  1472 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  0,
                                                  1,
                                                  1,
                                                  0,
                                                  1,
                                                  0,
                                                ) =>
                                                  1536 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  0,
                                                  1,
                                                  1,
                                                  0,
                                                  1,
                                                  1,
                                                ) =>
                                                  1600 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  1,
                                                  0,
                                                  0,
                                                  1,
                                                  0,
                                                  0,
                                                ) =>
                                                  1664 + read_black_code(input)
                                                (
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  1,
                                                  1,
                                                  0,
                                                  0,
                                                  1,
                                                  0,
                                                  1,
                                                ) =>
                                                  1728 + read_black_code(input)
                                                _ =>
                                                  raise Failure::Failure(
                                                    "bad black code",
                                                  )
                                              }
                                            }
                                          }
                                        }
                                      }
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

///|
priv enum CcittMode {
  Pass
  Horizontal
  Vertical(Int)
  Uncompressed
  EOFB
}

///|
fn read_ccitt_mode(input : @pdfio.Bitstream) -> CcittMode raise {
  let a = input.getbitint()
  if a == 1 {
    return CcittMode::Vertical(0)
  }
  let b = input.getbitint()
  let c = input.getbitint()
  match (a, b, c) {
    (0, 1, 1) => return CcittMode::Vertical(-1)
    (0, 1, 0) => return CcittMode::Vertical(1)
    (0, 0, 1) => return CcittMode::Horizontal
    _ => ()
  }
  let d = input.getbitint()
  match (a, b, c, d) {
    (0, 0, 0, 1) => return CcittMode::Pass
    _ => ()
  }
  let e = input.getbitint()
  let f = input.getbitint()
  match (a, b, c, d, e, f) {
    (0, 0, 0, 0, 1, 1) => return CcittMode::Vertical(-2)
    (0, 0, 0, 0, 1, 0) => return CcittMode::Vertical(2)
    _ => ()
  }
  let g = input.getbitint()
  match (a, b, c, d, e, f, g) {
    (0, 0, 0, 0, 0, 1, 1) => return CcittMode::Vertical(-3)
    (0, 0, 0, 0, 0, 1, 0) => return CcittMode::Vertical(3)
    _ => ()
  }
  let h = input.getbitint()
  let j = input.getbitint()
  let k = input.getbitint()
  let l = input.getbitint()
  let m = input.getbitint()
  match (a, b, c, d, e, f, g, h, j, k, l, m) {
    (0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1) => CcittMode::Uncompressed
    (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1) => {
      let a = input.getbitint()
      let b = input.getbitint()
      let c = input.getbitint()
      let d = input.getbitint()
      let e = input.getbitint()
      let f = input.getbitint()
      let g = input.getbitint()
      let h = input.getbitint()
      let j = input.getbitint()
      let k = input.getbitint()
      let l = input.getbitint()
      let m = input.getbitint()
      match (a, b, c, d, e, f, g, h, j, k, l, m) {
        (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1) => CcittMode::EOFB
        _ => raise Failure::Failure("Not a valid code on EOFB")
      }
    }
    _ => raise Failure::Failure("Not a valid code")
  }
}

///|
fn decode_ccittfax(
  k : Int,
  eol : Bool,
  eba : Bool,
  columns : Int,
  rows : Int,
  eob : Bool,
  bone : Bool,
  dra : Int,
  input : @pdfio.Input,
) -> @pdfio.MutableBytes raise CodecError {
  let _ = eol
  let _ = eob
  let _ = dra
  if k > 0 {
    raise CodecError::DecodeNotSupported("CCITTFax k > 0")
  }
  let (whiteval, blackval) = if bone { (0, 1) } else { (1, 0) }
  let output = @pdfio.BitstreamWrite::new()
  let bitstream = @pdfio.Bitstream::of_input(input)
  let mut column = 0
  let mut row = 0
  let mut refline = Array::make(columns, whiteval)
  let mut currline = Array::make(columns, 0)
  let mut white = true
  fn output_line(line : Array[Int]) -> Unit {
    for bit in line {
      output.putbit(bit)
    }
    output.align()
  }

  fn output_span(length : Int, value : Int) -> Unit raise {
    if length < 0 {
      raise Failure::Failure("Bad CCITT stream")
    }
    let end = column + length
    let bounded_end = if end > columns { columns } else { end }
    for idx = column; idx < bounded_end; idx = idx + 1 {
      currline[idx] = value
    }
    column = bounded_end
  }

  fn find_b1() -> Int {
    let mut pos = column
    if pos >= columns {
      return columns
    }
    let ref_color = refline[pos]
    while pos < refline.length() && refline[pos] == ref_color {
      pos = pos + 1
    }
    if pos > columns {
      columns
    } else {
      pos
    }
  }

  fn find_b2() -> Int {
    let mut pos = column
    if pos >= columns {
      return columns
    }
    let ref_color = refline[pos]
    while pos < refline.length() && refline[pos] == ref_color {
      pos = pos + 1
    }
    while pos < refline.length() && refline[pos] != ref_color {
      pos = pos + 1
    }
    if pos > columns {
      columns
    } else {
      pos
    }
  }

  try {
    while true {
      if column >= columns {
        output_line(currline)
        refline = currline
        currline = Array::make(columns, 0)
        column = 0
        white = true
        if eba {
          bitstream.align()
        }
        row = row + 1
        if row >= rows && rows > 0 {
          raise Failure::Failure("End_of_file")
        }
      } else if k < 0 {
        match read_ccitt_mode(bitstream) {
          CcittMode::Pass =>
            output_span(
              find_b2() - column,
              if white {
                whiteval
              } else {
                blackval
              },
            )
          CcittMode::Horizontal =>
            if white {
              let wlen = read_white_code(bitstream)
              let blen = read_black_code(bitstream)
              output_span(wlen, whiteval)
              output_span(blen, blackval)
            } else {
              let blen = read_black_code(bitstream)
              let wlen = read_white_code(bitstream)
              output_span(blen, blackval)
              output_span(wlen, whiteval)
            }
          CcittMode::Vertical(n) => {
            output_span(
              find_b1() + n - column,
              if white {
                whiteval
              } else {
                blackval
              },
            )
            white = !white
          }
          CcittMode::EOFB => raise Failure::Failure("End_of_file")
          CcittMode::Uncompressed =>
            raise CodecError::DecodeNotSupported("CCITT Uncompressed")
        }
      } else if k == 0 {
        let length = if white {
          read_white_code(bitstream)
        } else {
          read_black_code(bitstream)
        }
        if length == -1 {
          if column > 0 {
            output_span(columns - column, whiteval)
          }
        } else {
          output_span(length, if white { whiteval } else { blackval })
          white = !white
        }
      } else {
        raise CodecError::DecodeNotSupported("CCITT k")
      }
    }
    Array::new()
  } catch {
    Failure::Failure(msg) =>
      if msg == "End_of_file" {
        output.bytes()
      } else {
        raise CodecError::CouldntDecodeStream("Bad CCITT Stream")
      }
    _ => raise CodecError::CouldntDecodeStream("Bad CCITT Stream")
  }
}
