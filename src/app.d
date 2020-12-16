import std.stdio;
import std.file;
import std.algorithm.iteration: map, reduce;
import std.array: array, split;
import std.conv: to;

struct Line {
	uint times_covered;
	bool relevant;
}

struct Output {
	CoveredFile[] files;

	string writeFile(string prefix) {
		import core.stdc.time: time;
		import std.format: fmt = format;
		import std.path: base_name = baseName, build_path = buildPath
			, build_path = buildPath, absolute = absolutePath
			, is_absolute = isAbsolute;

		import std.algorithm.iteration: splitter, map, sum;

		const size_t lineLenAll = this.files.map!(file => file.lines.length).sum;
		const size_t idxLenAll = this.files.map!(file => file.indices.length).sum;

		double lineRateAll = idxLenAll / cast(double)lineLenAll;

		string res = `<?xml version="1.0"?>
<coverage version="5.3"
	timestamp="%s"
	lines-valid="%s"
	lines-covered="%s"
	line-rate="%s"
	branches-covered="0"
	branches-valid="0"
	branch-rate="0"
	complexity="0"
>
`.fmt(time(null), lineLenAll, idxLenAll, lineRateAll);

		res ~= "\t<sources>\n\t\t<source>./</source>\n\t</sources>\n";
		res ~=
`	<packages>
`;
		foreach(file; this.files) {
			const double lineRate = file.lines.length /
					cast(double)file.indices.length;

			string fpath = build_path(file.path[0 .. $-4].splitter('-')) ~ ".d";

			res ~=
`		<package name="covered" line-rate="%1$s" branch-rate="0" complexity="0">
			<classes>
				<class name="%2$s" filename="%2$s" complexity="0" line-rate="%1$s" branch-rate="0">
`.fmt(lineRate, fpath);

			res ~= "\t\t\t\t\t<lines>\n";
			foreach(i; file.indices) {
				res ~= "\t\t\t\t\t\t<line number=\"%s\" hits=\"%s\"/>\n".fmt(i, file.lines[i].times_covered);
			}
			res ~= "\t\t\t\t\t</lines>\n\t\t\t\t</class>\n\t\t\t</classes>\n\t\t</package>\n\t";
		}
		res ~= "</packages>\n</coverage>";
		return res;
	}
}

struct CoveredFile {
	string path;
	Line[] lines;
	size_t[] indices; // indices of lines that were covered

	this(string path) {
		import std.algorithm.searching: ends_with = endsWith;
		import std.string : strip;

		assert(path.ends_with(".lst"));
		this.path = path;

		size_t i = 0;
		this.lines = File(path)
			.byLineCopy
			.map!((x) {
				i++;
				Line l = {relevant:false};
				try {
					string s = x.split('|')[0].strip;
					l.times_covered = s.to!uint();
					l.relevant = true;
					indices ~= i;
				} catch(Exception e) {
				}
				return l;
			})
			.array;
	}
}

int main(string[] args) {
	import std.path: relative_path = relativePath, getcwd;
	import std.file: fspurt = write;

	if(args.length < 3) {
		writefln("Usage: <prefix> <coverages.lst>");
		return 1;
	}

	Output o;

	foreach(fn; args[2 .. $]) {
		auto c = CoveredFile(fn.relative_path);
		o.files ~= c;
	}

	writeln(getcwd());
	fspurt("cobertura.xml", o.writeFile(args[1]));

	return 0;
}
