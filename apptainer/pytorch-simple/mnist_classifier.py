import torch

# Images are 28x28 pixels
# There are 10 classes (0-9)


# Define the model
class MnistClassifier(torch.nn.Module):
    def __init__(self):
        super(MnistClassifier, self).__init__()
        self.conv1 = torch.nn.Conv2d(1, 32, kernel_size=5)
        self.conv2 = torch.nn.Conv2d(32, 64, kernel_size=5)
        self.conv3 = torch.nn.Conv2d(64, 128, kernel_size=5)
        self.conv4 = torch.nn.Conv2d(128, 128, kernel_size=5)
        self.fc1 = torch.nn.Linear(4608, 128)
        self.fc2 = torch.nn.Linear(128, 10)

    def forward(self, x):
        x = torch.relu(self.conv1(x))
        x = torch.relu(self.conv2(x))
        x = torch.relu(self.conv3(x))
        x = torch.relu(self.conv4(x))
        x = torch.max_pool2d(x, kernel_size=2)
        x = torch.flatten(x, 1)
        x = torch.relu(self.fc1(x))
        x = self.fc2(x)
        return x
