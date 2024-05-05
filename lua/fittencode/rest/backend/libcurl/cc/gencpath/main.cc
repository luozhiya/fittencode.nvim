#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>

// local M = {  cpath = '/home/qx/DataCenter/onWorking/fittencode.nvim/lua/fittencode/rest/backend/libcurl/api/?.so' } return M

int main() {
    std::filesystem::path ExePath = std::filesystem::canonical(std::filesystem::current_path());
    std::string Prefix = "local M = {  cpath = '";
    std::string Suffix = "/?.so' } return M\n";
    std::string Path = ExePath.string();
    for (size_t i = 0; (i = Path.find("\\", i)) != std::string::npos;) {
        Path.replace(i, 1, "/");
        i += 1;
    }
    std::string CPath = Prefix + Path + Suffix;
    std::ofstream OutputFile("cpath.lua", std::ios::out | std::ios::trunc);
    if (OutputFile.is_open()) {
        OutputFile << CPath;
        OutputFile.close();
        std::cout << "cpath --> cpath.lua. Done." << std::endl;
    } else {
        std::cerr << "Unable to open file for writing." << std::endl;
    }
    return 0;
}
