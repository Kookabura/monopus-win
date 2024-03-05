from PowerChute import PowerChute

def main():
    myups = PowerChute(server_ip="localhost", port="6547", username="tolkit", password="86UChyg$")
    result = myups.get_all_fields_values_as_json()
    print(str(result))
    return result

if __name__ == "__main__":
    main()

