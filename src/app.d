import cobertura;
import std.stdio : writefln;
import std.file : write;
import std.algorithm.iteration: map;
import std.array: array;
import std.path : relativePath;

int main(string[] args) {
	if(args.length < 3) {
		writefln("Usage: %s <prefix> <coverages.lst>", args[0]);
		return 1;
	}

	auto files = args[2..$].map!(path => parseLstFile(path.relativePath)).array;

	write("cobertura.xml", files.generateXmlFile());

	return 0;
}
