import cobertura;
import std.stdio : writefln;
import std.file : write, exists;
import std.algorithm.iteration: map, filter;
import std.array: array;
import std.path : relativePath;

int main(string[] args) {
	if(args.length < 3) {
		writefln("Usage: %s <prefix> <coverages.lst>", args[0]);
		return 1;
	}

	auto files = args[2..$].filter!(path => exists(path)).map!(path => parseLstFile(path.relativePath)).array;

	if (files.length == 0)
		return 0;

	write("cobertura.xml", files.generateXmlFile());

	return 0;
}
