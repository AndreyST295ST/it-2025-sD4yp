import gulp from "gulp";
import * as origSaas from "sass";
import gulpSass from "gulp-sass";
import postcss from "gulp-postcss";
import postcssImport from "postcss-import";
import autoprefixer from "autoprefixer";
import rename from "gulp-rename";

const sass = gulpSass(origSaas);

const destPath = "../../server/www/css";

gulp.task("style", async () => {
  gulp
    .src(["./src/style.scss"])
    .pipe(
      sass({ style: "compressed", sourceComments: false }).on(
        "error",
        sass.logError
      )
    )
    .pipe(postcss([postcssImport(), autoprefixer()]))
    .pipe(rename({ extname: ".min.css" }))
    .pipe(gulp.dest(destPath));
});

gulp.task("default", gulp.series(["style"]));
