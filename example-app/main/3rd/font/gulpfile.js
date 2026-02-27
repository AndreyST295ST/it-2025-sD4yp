import gulp from "gulp";
import ttf2woff from "gulp-ttf2woff";
import ttf2woff2 from "gulp-ttf2woff2";

const destPath = "../../server/www/font";

gulp.task("toWoff", async () => {
  gulp
    .src(["./src/**/*.ttf"], {
      encoding: false,
      removeBOM: false,
    })
    .pipe(ttf2woff())
    .pipe(gulp.dest(destPath));
});

gulp.task("toWoff2", async () => {
  gulp
    .src(["./src/**/*.ttf"], {
      encoding: false,
      removeBOM: false,
    })
    .pipe(ttf2woff2())
    .pipe(gulp.dest(destPath));
});

gulp.task("default", gulp.series(["toWoff", "toWoff2"]));
